#!/usr/bin/env bash
# Regression cases for .github/scripts/secret-check.sh, run in throwaway
# repositories with synthetic values. Each case checks the exit status and
# that no synthetic value appears in the script's output.
#
# usage: .github/tests/secret-check/run.sh
set -euo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
script="$root/.github/scripts/secret-check.sh"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
# The cases run outside the repository, where mise has no tool versions, so
# the script is pointed at the repository's pinned tools directly.
export SECRET_CHECK_TOOLS="$scratch/tools"
mkdir "$SECRET_CHECK_TOOLS"
for t in gitleaks jq yq; do
  ln -s "$(cd "$root" && mise which "$t")" "$SECRET_CHECK_TOOLS/$t"
done
failed=0
passed=0

rnd() { LC_ALL=C tr -dc "$1" < /dev/urandom | head -c "$2" || true; }
plain="plain$(rnd a-z 16)"
age="AGE-SECRET-KEY-1$(rnd QPZRY9X8GF2TVDW0S3JN54KHCE6MUA7L 58)"
token="ghp_$(rnd A-Za-z0-9 36)"
# Short enough to fall inside the source text gitleaks shows beside a finding.
password="pw$(rnd a-z 6)"
alias_name="alias$(rnd a-z 16)"
zero=0000000000000000000000000000000000000000

# check NAME WANT COMMAND...: the exit status must be WANT, and no synthetic
# value may appear in the output.
check() {
  local name="$1" want="$2" got=0 value leaked=""
  shift 2
  "$@" > "$scratch/out" 2>&1 || got=$?
  for value in "$plain" "$age" "$token" "$password" "$alias_name"; do
    if grep -qF -- "$value" "$scratch/out"; then leaked=", and its output shows a synthetic value"; fi
  done
  if [ "$got" = "$want" ] && [ -z "$leaked" ]; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    echo "FAIL $name: exit $got, want $want$leaked"
  fi
}

# repo: a fresh case repository with one commit, as the working directory.
repo() {
  rm -rf "$scratch/repo" "$scratch"/*.git
  git init -q -b main "$scratch/repo"
  cd "$scratch/repo"
  git config user.email test@example.invalid
  git config user.name test
  git config commit.gpgsign false
  git commit -q --allow-empty -m init
  base="$(git rev-parse HEAD)"
}
commit() { git add -A && git commit -q --no-verify -m change; }
# secret PATH KIND VALUE: a one-key Secret-shaped manifest.
secret() {
  mkdir -p "$(dirname "$1")"
  printf -- '---\napiVersion: v1\nkind: %s\nmetadata:\n  name: x\nstringData:\n  T: %s\n' "$2" "$3" > "$1"
}
range() { bash "$script" range "$base..HEAD"; }
staged() { bash "$script" staged; }

# Value check, one commit each.
repo; secret k/s.yaml Secret "$plain"; commit; check "plaintext Secret" 1 range
repo; secret k/s.yaml Secret op://vault/item/field; commit; check "op:// Secret" 0 range
repo; secret k/s.yaml ConfigMap "$plain"; commit; check "plaintext ConfigMap" 0 range
repo; mkdir k; printf -- '---\n- name: a\n  value: %s\n---\nplain scalar\n' "$plain" > k/l.yaml; commit
check "list and scalar documents" 0 range
repo; secret k/s.yaml '"Secret"' "$plain"; commit; check "quoted kind value" 1 range
repo; secret k/s.yaml 'Secret # note' "$plain"; commit; check "commented kind" 1 range
repo; mkdir k; printf -- '---\n"kind": Secret\nmetadata: {name: x}\nstringData: {T: %s}\n' "$plain" > k/s.yaml; commit
check "quoted kind key" 1 range
repo; mkdir k; printf '{"kind": "Secret", "metadata": {"name": "x"}, "stringData": {"T": "%s"}}\n' "$plain" > k/s.yaml; commit
check "flow mapping" 1 range
repo; mkdir k; printf -- '---\nkind: Secret\nmetadata:\n  name: x\nstringData: %s\n' "$plain" > k/s.yaml; commit
check "scalar stringData" 1 range
repo; mkdir k; printf -- '---\nkind: Secret\nmetadata:\n  name: x\nstringData:\n  T: %s\n\tbad: tab\n' "$plain" > k/s.yaml; commit
check "unparseable Secret" 1 range
repo; mkdir k; printf -- '---\nkind: Secret\nmetadata:\n  name: x\nstringData:\n  password: *%s\n' "$alias_name" > k/s.yaml; commit
check "unquoted alias, value kept out of the output" 1 range
repo; secret "k/my secret.yaml" Secret "$plain"; commit; check "space in path" 1 range
repo; secret "k/café.yaml" Secret "$plain"; commit; check "non-ASCII path" 1 range
repo; secret "k/[x].yaml" Secret "$plain"; commit; check "glob characters in path" 1 range
repo; mkdir k; printf -- '---\nkind: Secret\nmetadata:\n  name: s\nstringData:\n  A: ENC[AES256_GCM,data:a,iv:b,tag:c,type:str]\n  B: %s\nsops:\n  mac: ENC[x]\n' "$plain" > k/s.sops.yaml; commit
check "SOPS file, one plaintext value" 1 range
repo; mkdir k; printf -- '---\nkind: Secret\nmetadata:\n  name: s\nstringData:\n  A: ENC[AES256_GCM,data:a,iv:b,tag:c,type:str]\nsops:\n  mac: ENC[x]\n' > k/s.sops.yaml; commit
check "SOPS file, all encrypted" 0 range

# gitleaks.
repo; echo "key: $age" > age.txt; commit; check "age key" 1 range
repo; echo "config: token=$token p=$password" > c.txt; commit
check "token beside a password, neither in the output" 1 range
repo; echo "config: token=$token p=$password" > c.txt; git add -A
check "staged token beside a password, neither in the output" 1 staged

# Ranges: added and removed again, and merges.
repo; echo "key: $age" > age.txt; commit; git rm -q age.txt; commit
check "key added then removed" 1 range
repo; git switch -q -c side; echo s > side.txt; commit; git switch -q main; echo m > main.txt; commit
base="$(git rev-parse HEAD)"; git merge -q --no-commit side > /dev/null 2>&1 || true
secret k/m.yaml Secret "$plain"; git add -A; git commit -q --no-verify -m merge
check "merge adds a plaintext Secret" 1 range
repo; git switch -q -c side; echo s > side.txt; commit; git switch -q main; echo m > main.txt; commit
base="$(git rev-parse HEAD)"; git merge -q --no-commit side > /dev/null 2>&1 || true
echo "key: $age" > age.txt; git add -A; git commit -q --no-verify -m merge
check "merge adds an age key" 1 range

# Staged: only the index counts, even while another process holds its lock.
repo; secret k/s.yaml Secret "$plain"; git add -A; check "staged plaintext Secret" 1 staged
repo; secret k/s.yaml Secret "$plain"; git add -A; touch .git/index.lock
check "staged plaintext Secret, index locked" 1 staged
rm -f .git/index.lock
repo; secret k/s.yaml Secret "$plain"; git add -A; secret k/s.yaml Secret op://vault/item/field
check "plaintext staged, fixed only in the working tree" 1 staged
repo; echo clean > clean.txt; git add -A; check "staged clean change" 0 staged

# Push: what the target remote already has is skipped; nothing else is.
push() { # TARGET: push HEAD as a new branch
  printf 'refs/heads/b %s refs/heads/b %s\n' "$(git rev-parse HEAD)" "$zero" | bash "$script" push "$1"
}
repo; git init -q --bare "$scratch/other.git"; git init -q --bare "$scratch/target.git"
git remote add other "$scratch/other.git"; git remote add target "$scratch/target.git"
git push -q --no-verify target main; git fetch -q target
git switch -q -c b; secret k/s.yaml Secret "$plain"; commit; git push -q --no-verify other b; git fetch -q other
check "leak already on another remote, pushed to a named remote" 1 push target
check "leak already on another remote, pushed to an unknown URL" 1 push "file://$scratch/elsewhere.git"
repo; git init -q --bare "$scratch/target.git"; git remote add target "$scratch/target.git"
git switch -q -c b; secret k/s.yaml Secret "$plain"; commit; git push -q --no-verify target b; git fetch -q target
echo clean > clean.txt; commit
check "a URL matching a configured remote skips what it has" 0 push "file://$scratch/target.git"
repo; secret k/s.yaml Secret "$plain"; commit; git update-ref refs/remotes/gh/main HEAD
git remote add gh https://github.com/example/repo.git; echo clean > clean.txt; commit
check "an SSH URL matches the HTTPS remote" 0 push git@github.com:example/repo.git

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
