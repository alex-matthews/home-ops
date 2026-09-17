#!/usr/bin/env bash
# Chart verification coverage (ADR-0003, #1967, #2145). Offline: git and yq only.
#
# Two questions, answered against git refs so fixtures can build the trees.
# First, over the whole head tree: every YAML document of kind OCIRepository
# under kubernetes/ lives in a file named ocirepository.yaml, has a name and
# URL no other source shares, and carries exactly one of a verify block or
# the annotation home-ops/chart-verify-exclusion-reason with a known value;
# a verifier-gap reason names a key fingerprint, sha256: and 64 hex digits,
# and every fingerprint names a key committed under .github/keys/. Second,
# over the diff: each head source is matched to a base source by identity,
# the manifest's name and URL, and failing that by path, so a moved file and
# a renamed source are both modifications; a verify block removed or an
# identity changed fails unless the change is declared (the verify/declared
# label), and an annotation never satisfies that guard.
#
# usage: chart-signing-coverage.sh BASE_REF HEAD_REF [true|false]
# The third argument says whether the change is declared. Output uses GitHub
# workflow commands; exit 1 on any error, and exit 2 when a ref cannot be read.
set -euo pipefail

BASE=${1:?base ref}; HEAD=${2:?head ref}; DECLARED=${3:-false}
ANNOTATION_REASON=home-ops/chart-verify-exclusion-reason
ANNOTATION_KEY=home-ops/chart-verify-key-fingerprint
REASONS='unsigned keyed-unpinned verifier-gap unverifiable'
KEYS_DIR=.github/keys
# tojson of an absent verify block, base64-encoded as the source rows carry it.
EMPTY_VERIFY="$(printf '""\n' | base64)"

tool() {
  if [ -n "${CHART_SIGNING_TOOLS:-}" ]; then "$CHART_SIGNING_TOOLS/$1" "${@:2}"; else mise exec -- "$@"; fi
}
failed=0
err() { echo "::error file=$1::$2"; failed=1; }
die() { echo "::error::$1"; exit 2; }

for ref in "$BASE" "$HEAD"; do
  git rev-parse --verify --quiet "$ref^{tree}" > /dev/null || die "ref '$ref' cannot be read"
done

# sources REF -> lines "path<TAB>name<TAB>url<TAB>reason<TAB>fingerprint<TAB>verify-base64" for every
# OCIRepository document. The ref's kubernetes/ tree is extracted and every YAML file in it is parsed in one
# yq pass that checks each document's top-level kind, so no textual prefilter can miss a source; a git or
# yq failure aborts the run. Absent annotations are "-" so every row keeps six columns (bash's read
# collapses consecutive tabs).
sources() {
  local ref=$1 dir path
  # A tree without kubernetes/ has no sources; git archive would refuse the pathspec.
  [ -n "$(git ls-tree "$ref" -- kubernetes)" ] || return 0
  dir="$(mktemp -d)"
  git archive "$ref" -- kubernetes | tar -x -C "$dir" || { rm -rf "$dir"; die "git archive failed for '$ref'"; }
  local -a files=()
  while IFS= read -r path; do files+=("$path"); done < <(cd "$dir" && find kubernetes \( -name '*.yaml' -o -name '*.yml' \) -type f | sort)
  if [ "${#files[@]}" -gt 0 ]; then
    (cd "$dir" && tool yq -r "select(.kind == \"OCIRepository\") | [filename, (.metadata.name // \"\"), (.spec.url // \"\"), (.metadata.annotations[\"$ANNOTATION_REASON\"] // \"-\"), (.metadata.annotations[\"$ANNOTATION_KEY\"] // \"-\"), ((.spec.verify // \"\") | tojson | @base64)] | join(\"\t\")" "${files[@]}") || { rm -rf "$dir"; die "could not parse the manifests at '$ref'"; }
  fi
  rm -rf "$dir"
}
blank() { [ "$1" = - ] && printf '' || printf '%s' "$1"; }
in_list() { printf '%s\n' "$2" | tr ' ' '\n' | grep -Fqx -- "$1"; }

# Committed key fingerprints at HEAD.
fingerprints=""
while IFS= read -r k; do
  [ -n "$k" ] || continue
  fp="$(git show "$HEAD:$k" | openssl pkey -pubin -outform DER 2> /dev/null | openssl dgst -sha256 | awk '{print $NF}')"
  [ -n "$fp" ] || err "$k" "committed key is not a readable public key"
  fingerprints+="$fp"$'\n'
done < <(git ls-tree -r --name-only "$HEAD" -- "$KEYS_DIR" 2> /dev/null | grep '\.pem$' || true)

head_sources="$(sources "$HEAD")" || exit 2
base_sources="$(sources "$BASE")" || exit 2

# Whole-tree rules.
while IFS=$'\t' read -r path name url reason fp verify; do
  [ -n "$path" ] || continue
  reason="$(blank "$reason")"; fp="$(blank "$fp")"
  [ "$(basename "$path")" = ocirepository.yaml ] || err "$path" "OCIRepository $name must live in a file named ocirepository.yaml so the chart checks see it"
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
  if [ "$reason" = verifier-gap ] && [ -z "$fp" ]; then
    err "$path" "$name declares verifier-gap without $ANNOTATION_KEY"
  fi
  if [ -n "$fp" ] && [ "$reason" != verifier-gap ]; then
    err "$path" "$name carries $ANNOTATION_KEY but its reason is '${reason:-none}'; only verifier-gap names a key"
  fi
  if [ -n "$fp" ]; then
    if ! printf '%s\n' "$fp" | grep -Eq '^sha256:[0-9a-f]{64}$'; then
      err "$path" "$name names the key fingerprint '$fp', which is not sha256: followed by 64 hex digits"
    elif ! printf '%s' "$fingerprints" | grep -Fqx -- "${fp#sha256:}"; then
      err "$path" "$name names the key fingerprint '$fp' and no key under $KEYS_DIR matches it"
    fi
  fi
done <<< "$head_sources"

# Diff rules: match by identity (name and URL), then by path.
find_base() { # name url path -> the base row's verify field, or ABSENT
  printf '%s\n' "$base_sources" | awk -F'\t' -v n="$1" -v u="$2" -v p="$3" '
    $2 == n && $3 == u { print $6; found = 1; exit }
    $1 == p { bypath = $6 }
    END { if (!found) print (bypath == "" ? "ABSENT" : bypath) }'
}
matched_base=""
while IFS=$'\t' read -r path name url reason fp after; do
  [ -n "$path" ] || continue
  reason="$(blank "$reason")"
  before="$(find_base "$name" "$url" "$path")"
  if [ "$before" = ABSENT ]; then
    if [ "$after" = "$EMPTY_VERIFY" ]; then echo "new source without a verify block, declared ${reason:-none}: $path"; else echo "new source with a verify block: $path"; fi
    continue
  fi
  matched_base+="$name $url $path"$'\n'
  [ "$before" = "$after" ] && continue
  if [ "$after" = "$EMPTY_VERIFY" ]; then
    msg="verify block removed"
  elif [ "$before" = "$EMPTY_VERIFY" ]; then
    echo "verify block added: $path"; continue
  else
    msg="verify identity changed"
  fi
  if [ "$DECLARED" = true ]; then
    echo "::warning file=$path::$msg (declared with the verify/declared label)"
  else
    err "$path" "$msg without the verify/declared label; ADR-0003 requires the re-observed identity and the reason in the pull request"
  fi
done <<< "$head_sources"
while IFS=$'\t' read -r path name url _ _ _; do
  [ -n "$path" ] || continue
  if ! printf '%s' "$matched_base" | grep -Fq -- "$name $url " && ! printf '%s' "$matched_base" | grep -Fq -- " $path"; then
    echo "source removed: $path ($name)"
  fi
done <<< "$base_sources"
exit "$failed"
