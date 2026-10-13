#!/usr/bin/env bash
# Secret checks for the pre-commit and pre-push hooks and CI. Offline: git,
# gitleaks and yq.
#
# gitleaks finds keys and tokens but not an arbitrary plaintext value, so every
# value in a Secret or SOPS file must also be SOPS-encrypted or a 1Password
# reference. A `sops:` block or `sops filestatus` passes a file with one
# plaintext value. Output names files and keys, never values. A file that
# cannot be read or parsed fails rather than passing unchecked.
#
# usage: secret-check.sh staged
#        secret-check.sh push <remote>            (refs on stdin, as git gives them)
#        secret-check.sh range <git log arguments>
set -euo pipefail

tool() { mise exec -- "$@"; }

secret_kind='^kind:[[:space:]]*["'\'']?Secret["'\'']?[[:space:]]*(#.*)?$'
sops_name='[^/]\.sops\.ya?ml$'

sops_only() {
  local file
  while IFS= read -r -d '' file; do
    if [[ $file =~ $sops_name ]]; then printf '%s\0' "$file"; fi
  done
}

# candidates <commit, or empty for the index> [<path>...]: NUL-separated Secret
# and SOPS files.
candidates() {
  local rev="$1" file
  shift
  {
    if [ -z "$rev" ]; then
      git grep -z -l --cached -E "$secret_kind" -- "$@" || true
      git ls-files -z -- "$@" | sops_only
    else
      git grep -z -l -E "$secret_kind" "$rev" -- "$@" || true
      git ls-tree -r -z --name-only "$rev" -- "$@" | sops_only
    fi
  } | while IFS= read -r -d '' file; do
    file="${file#"$rev":}"
    if [[ $file =~ \.ya?ml$ ]]; then printf '%s\0' "$file"; fi
  done | sort -zu
}

# values <commit, or empty for the index> [<path>...]: fail on a Secret or SOPS
# file whose data or stringData holds anything but ENC[ or op:// values.
values() {
  local rev="$1" file all bad key status=0
  shift
  while IFS= read -r -d '' file; do
    all=false
    if [[ $file =~ $sops_name ]]; then all=true; fi
    # shellcheck disable=SC2016 # $name is a yq variable
    if ! bad="$(git show "$rev:$file" | ALL=$all tool yq -N '
      select(strenv(ALL) == "true" or .kind == "Secret") | .metadata.name as $name
      | ((.data // {}), (.stringData // {})) | to_entries[]
      | select((.value | tag) != "!!str" or (.value | test("^(ENC\[|op://)") | not))
      | $name + "/" + .key')"; then
      echo "$file: could not be read or parsed, so it is not checked" >&2
      status=1
      continue
    fi
    while IFS= read -r key; do
      [ -n "$key" ] || continue
      echo "$file: $key is neither SOPS-encrypted nor a 1Password reference" >&2
      status=1
    done <<< "$bad"
  done < <(candidates "$rev" "$@")
  return "$status"
}

# range <git log arguments>: scan every commit in the range, merges against
# their first parent.
range() {
  local commit file status=0 files
  tool gitleaks git --redact --no-banner --verbose --log-opts="$* --diff-merges=first-parent" . || status=1
  for commit in $(git rev-list "$@"); do
    files=()
    while IFS= read -r -d '' file; do
      files+=("$file")
    done < <(git diff-tree -z --no-commit-id --name-only -r --root \
      --diff-merges=first-parent --diff-filter=d "$commit")
    [ "${#files[@]}" -gt 0 ] || continue
    GIT_LITERAL_PATHSPECS=1 values "$commit" "${files[@]}" || status=1
  done
  return "$status"
}

case "${1:-}" in
  staged)
    status=0
    tool gitleaks git --staged --redact --no-banner --verbose . || status=1
    values "" || status=1
    exit "$status"
    ;;
  push)
    remote="${2:?usage: $0 push <remote>}"
    # Commits on the target remote are checked already; a push to a URL
    # excludes what any remote has.
    pushed=(--remotes)
    git remote | grep -qxF -- "$remote" && pushed=(--remotes="$remote")
    status=0
    zero="$(git hash-object --stdin < /dev/null | tr '[:xdigit:]' 0)"
    while read -r _ local_sha _ remote_sha; do
      [ "$local_sha" = "$zero" ] && continue
      # A new branch, or a remote tip this clone lacks: everything the remote lacks.
      if [ "$remote_sha" = "$zero" ] || ! git cat-file -e "$remote_sha^{commit}" 2>/dev/null; then
        range "$local_sha" --not "${pushed[@]}" || status=1
      else
        range "$remote_sha..$local_sha" || status=1
      fi
    done
    exit "$status"
    ;;
  range)
    shift
    range "$@"
    ;;
  *)
    echo "usage: $0 staged | push <remote> | range <git log arguments>" >&2
    exit 2
    ;;
esac
