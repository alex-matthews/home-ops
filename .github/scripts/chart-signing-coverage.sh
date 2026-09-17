#!/usr/bin/env bash
# Chart verification coverage (ADR-0003, #1967, #2145). Offline: git and yq only.
#
# Every OCIRepository needs a verify block or a valid exclusion reason, a
# unique (name, URL) pair, and a single-document ocirepository.yaml file.
# Compare verify blocks by (name, URL), falling back to path: an exclusion
# annotation never authorizes removal or alteration without verify/declared.
#
# usage: chart-signing-coverage.sh BASE_REF HEAD_REF [true|false]
# The third argument is whether the PR has verify/declared. Exit 1 on policy
# violations, 2 on unreadable refs/manifests; diagnostics use workflow commands.
set -euo pipefail

BASE=${1:?base ref}; HEAD=${2:?head ref}; DECLARED=${3:-false}
ANNOTATION_REASON=home-ops/chart-verify-exclusion-reason
REASONS='unsigned keyed-unpinned verifier-gap unverifiable'
# tojson of an absent verify block, base64-encoded as the source rows carry it.
EMPTY_VERIFY="$(printf '""\n' | base64)"

tool() {
  if [ -n "${CHART_SIGNING_TOOLS:-}" ]; then "$CHART_SIGNING_TOOLS/$1" "${@:2}"; else mise exec -- "$@"; fi
}
failed=0
err() { echo "::error file=$1::$2"; failed=1; }
die() { echo "::error::$1" >&2; exit 2; }

for ref in "$BASE" "$HEAD"; do
  git rev-parse --verify --quiet "$ref^{tree}" > /dev/null || die "ref '$ref' cannot be read"
done

# sources REF -> TSV: path, name, URL, reason, encoded verify block, document count.
# Parse every YAML document: textual kind searches miss valid quoted/escaped
# spellings. Use "-" for absent reasons because Bash collapses empty tab fields.
sources() {
  local ref=$1 dir path
  # A tree without kubernetes/ has no sources; git archive would refuse the pathspec.
  [ -n "$(git ls-tree "$ref" -- kubernetes)" ] || return 0
  dir="$(mktemp -d)"
  git archive "$ref" -- kubernetes | tar -x -C "$dir" || { rm -rf "$dir"; die "git archive failed for '$ref'"; }
  local -a files=()
  while IFS= read -r path; do files+=("$path"); done < <(cd "$dir" && find kubernetes \( -name '*.yaml' -o -name '*.yml' \) -type f | sort)
  if [ "${#files[@]}" -gt 0 ]; then
    (cd "$dir" && tool yq ea -r "[. | {\"path\": filename, \"doc\": .}] | group_by(.path) | .[] as \$docs | \$docs[] | .path as \$path | .doc | select(.kind == \"OCIRepository\") | [\$path, (.metadata.name // \"\"), (.spec.url // \"\"), (.metadata.annotations[\"$ANNOTATION_REASON\"] // \"-\"), ((.spec.verify // \"\") | tojson | @base64), (\$docs | length)] | join(\"\t\")" "${files[@]}") || { rm -rf "$dir"; die "could not parse the manifests at '$ref'"; }
  fi
  rm -rf "$dir"
}
blank() { [ "$1" = - ] && printf '' || printf '%s' "$1"; }
in_list() { printf '%s\n' "$2" | tr ' ' '\n' | grep -Fqx -- "$1"; }

head_sources="$(sources "$HEAD")" || exit 2
base_sources="$(sources "$BASE")" || exit 2

# Whole-tree rules.
while IFS=$'\t' read -r path name url reason verify documents; do
  [ -n "$path" ] || continue
  reason="$(blank "$reason")"
  [ "$(basename "$path")" = ocirepository.yaml ] || err "$path" "OCIRepository $name must live in a file named ocirepository.yaml so the chart checks see it"
  [ "$documents" = 1 ] || err "$path" "OCIRepository $name must be the only YAML document in its file"
  [ -n "$name" ] && [ -n "$url" ] || err "$path" "OCIRepository has no name or no spec.url"
  if [ "$(printf '%s\n' "$head_sources" | awk -F'\t' -v n="$name" -v u="$url" '$2 == n && $3 == u' | wc -l)" -gt 1 ]; then
    err "$path" "$name at $url is declared more than once; every source needs its own name and URL"
  fi
  if [ "$verify" != "$EMPTY_VERIFY" ] && [ -n "$reason" ]; then
    err "$path" "$name has both a verify block and $ANNOTATION_REASON; a verified source carries no exclusion reason"
  elif [ "$verify" = "$EMPTY_VERIFY" ] && [ -z "$reason" ]; then
    err "$path" "$name has no verify block and no $ANNOTATION_REASON; add a verify block after re-validating the identity (ADR-0003), or declare one of: ${REASONS// /, }"
  fi
  if [ -n "$reason" ] && ! in_list "$reason" "$REASONS"; then
    err "$path" "$name declares the unknown exclusion reason '$reason'; valid values: ${REASONS// /, }"
  fi
done <<< "$head_sources"

# Diff rules: match by identity (name and URL), then by path.
find_base() { # name url path -> base path and verify field, or ABSENT
  printf '%s\n' "$base_sources" | awk -F'\t' -v n="$1" -v u="$2" -v p="$3" '
    $2 == n && $3 == u { print $1 "\t" $5; found = 1; exit }
    $1 == p { bypath = $1 "\t" $5 }
    END { if (!found) print (bypath == "" ? "ABSENT" : bypath) }'
}
guard() {
  local path=$1 msg=$2
  if [ "$DECLARED" = true ]; then
    echo "::warning file=$path::$msg (declared with the verify/declared label)"
  else
    err "$path" "$msg without the verify/declared label; ADR-0003 requires the re-observed identity and the reason in the pull request"
  fi
}
matched_base=""
while IFS=$'\t' read -r path name url reason after _; do
  [ -n "$path" ] || continue
  reason="$(blank "$reason")"
  before="$(find_base "$name" "$url" "$path")"
  if [ "$before" = ABSENT ]; then
    if [ "$after" = "$EMPTY_VERIFY" ]; then echo "new source without a verify block, declared ${reason:-none}: $path"; else echo "new source with a verify block: $path"; fi
    continue
  fi
  matched_base+="${before%%$'\t'*}"$'\n'
  before="${before#*$'\t'}"
  [ "$before" = "$after" ] && continue
  if [ "$after" = "$EMPTY_VERIFY" ]; then
    msg="verify block removed"
  elif [ "$before" = "$EMPTY_VERIFY" ]; then
    echo "verify block added: $path"; continue
  else
    msg="verify identity changed"
  fi
  guard "$path" "$msg"
done <<< "$head_sources"
while IFS=$'\t' read -r path name url _ before _; do
  [ -n "$path" ] || continue
  if ! printf '%s' "$matched_base" | grep -Fxq -- "$path"; then
    if [ "$before" != "$EMPTY_VERIFY" ]; then
      guard "$path" "verified source removed"
    else
      echo "source removed: $path ($name)"
    fi
  fi
done <<< "$base_sources"
exit "$failed"
