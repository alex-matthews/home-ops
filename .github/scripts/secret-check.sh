#!/usr/bin/env bash
# Secret checks for the pre-commit and pre-push hooks and CI. Offline: git,
# gitleaks, jq and yq. Tests: .github/tests/secret-check/run.sh.
#
# gitleaks finds keys and tokens but not an arbitrary plaintext value, so every
# value in a Secret or SOPS file must also be SOPS-encrypted or a 1Password
# reference. A `sops:` block or `sops filestatus` passes a file with one
# plaintext value. Output names files, keys and rules, never values. A file
# that cannot be read or parsed fails rather than passing unchecked.
#
# usage: secret-check.sh staged
#        secret-check.sh push <remote>            (refs on stdin, as git gives them)
#        secret-check.sh range <git log arguments>
set -euo pipefail

tool() {
  if [ -n "${SECRET_CHECK_TOOLS:-}" ]; then "$SECRET_CHECK_TOOLS/$1" "${@:2}"; else mise exec -- "$@"; fi
}

sops_name='[^/]\.sops\.ya?ml$'

# leaks <gitleaks git arguments>: gitleaks prints source text around a finding,
# which --redact does not cover, so only locations and rules are shown.
leaks() {
  local report status=0
  report="$(mktemp)"
  tool gitleaks git --redact --no-banner --log-level error --report-format json \
    --report-path "$report" "$@" . || status=$?
  if [ "$status" -ne 0 ]; then
    tool jq -r '.[] | "\(.File):\(.StartLine): gitleaks \(.RuleID)\(if .Commit == "" then "" else " in " + .Commit[0:8] end)"' \
      "$report" >&2 || true
  fi
  rm -f "$report"
  return "$status"
}

# values <commit, or empty for the index> <path>...: fail on a Secret or SOPS
# file whose data or stringData holds anything but ENC[ or op:// values. yq,
# not a text match, decides what is a Secret.
values() {
  local rev="$1" file all bad key status=0
  shift
  for file in "$@"; do
    [[ $file =~ \.ya?ml$ ]] || continue
    all=false
    if [[ $file =~ $sops_name ]]; then all=true; fi
    # yq's parse errors can quote the value they stopped at.
    # shellcheck disable=SC2016 # $name is a yq variable
    if ! bad="$(git show "$rev:$file" | ALL=$all tool yq -N '
      select(tag == "!!map") | select(strenv(ALL) == "true" or .kind == "Secret") | .metadata.name as $name
      | ((.data // {}), (.stringData // {})) | to_entries[]
      | select((.value | tag) != "!!str" or (.value | test("^(ENC\[|op://)") | not))
      | $name + "/" + .key' 2>/dev/null)"; then
      echo "$file: could not be read or parsed, so it is not checked" >&2
      status=1
      continue
    fi
    while IFS= read -r key; do
      [ -n "$key" ] || continue
      echo "$file: $key is neither SOPS-encrypted nor a 1Password reference" >&2
      status=1
    done <<< "$bad"
  done
  return "$status"
}

# range <git log arguments>: scan every commit in the range, merges against
# their first parent.
range() {
  local commit file status=0 files
  leaks --log-opts="$* --diff-merges=first-parent" || status=1
  for commit in $(git rev-list "$@"); do
    files=()
    while IFS= read -r -d '' file; do
      files+=("$file")
    done < <(git diff-tree -z --no-commit-id --name-only -r --root \
      --diff-merges=first-parent --diff-filter=d "$commit")
    [ "${#files[@]}" -gt 0 ] || continue
    values "$commit" "${files[@]}" || status=1
  done
  return "$status"
}

# address <remote URL>: host and path, so HTTPS and SSH forms compare equal.
address() {
  sed -E 's#^[a-z+]+://##; s#^[^@/]*@##; s#^([^/:]+):([^0-9])#\1/\2#; s#\.git/?$##; s#/$##' <<< "$1"
}

case "${1:-}" in
  staged)
    status=0
    leaks --staged || status=1
    files=()
    while IFS= read -r -d '' file; do
      files+=("$file")
    done < <(git diff --cached --name-only -z --diff-filter=d)
    if [ "${#files[@]}" -gt 0 ]; then values "" "${files[@]}" || status=1; fi
    exit "$status"
    ;;
  push)
    target="${2:?usage: $0 push <remote>}"
    # The target remote's own commits are not published by this push. A URL
    # matches a configured remote with the same address; any other target
    # gets every reachable commit checked.
    pushed=()
    for name in $(git remote); do
      if [ "$name" = "$target" ] || [ "$(address "$(git remote get-url "$name")")" = "$(address "$target")" ]; then
        pushed+=(--remotes="$name")
      fi
    done
    status=0
    zero="$(git hash-object --stdin < /dev/null | tr '[:xdigit:]' 0)"
    while read -r _ local_sha _ remote_sha; do
      [ "$local_sha" = "$zero" ] && continue
      if [ "$remote_sha" != "$zero" ] && git cat-file -e "$remote_sha^{commit}" 2>/dev/null; then
        range "$remote_sha..$local_sha" || status=1
      elif [ "${#pushed[@]}" -gt 0 ]; then
        range "$local_sha" --not "${pushed[@]}" || status=1
      else
        range "$local_sha" || status=1
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
