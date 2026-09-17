#!/usr/bin/env bash
# Discover material on unsigned chart sources (#2145). No signature verification.
# Resolve the manifest's pin, check legacy signature/attestation tags and direct
# OCI referrers. Known SBOM types are ignored; other material needs human review.
# Signed exclusions are listed as skipped. An undeclared source can be inspected
# locally, but Coverage requires a declaration before merge.
# FINDINGS_OUT/ERRORS_OUT receive Markdown; stdout is TSV (file, ref, digest,
# result, detail). The caller handles findings/errors; tool injection is for tests.
set -euo pipefail

[ "$#" -gt 0 ] || { echo "usage: $0 FILE..." >&2; exit 64; }
: "${FINDINGS_OUT:=/dev/null}" "${ERRORS_OUT:=/dev/null}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

tool() {
  if [ -n "${CHART_SIGNING_TOOLS:-}" ]; then "$CHART_SIGNING_TOOLS/$1" "${@:2}"; else mise exec -- "$@"; fi
}
esc() { printf '%s' "$1" | tr '\n\r\t' '   ' | tr -d '`<>[]()*_#|' | cut -c1-160; }
row() { printf '%s\t%s\t%s\t%s\t%s\n' "$file" "$ref" "$digest" "$1" "$2"; }
inconclusive() {
  printf -- "- \`%s\`: %s (\`%s\`)\n" "$ref" "$1" "$file" >> "$ERRORS_OUT"
  row inconclusive "$1"
}
# Only an explicit registry not-found response establishes absence.
absent_text() { grep -Eq '^Error response from registry: failed to (find |resolve digest: ).*: not found$'; }
# lookup NAME ALLOW_ABSENT CMD... -> LOOKUP, LOOKUP_ERR, stdout in work/response.
lookup() {
  local name=$1 allow_absent=$2 attempt; shift 2
  LOOKUP=inconclusive; LOOKUP_ERR=""
  for attempt in 1 2; do
    if "$@" > "$work/response" 2> "$work/error"; then LOOKUP=present; return 0; fi
    if [ "$allow_absent" = true ] && absent_text < "$work/error"; then LOOKUP=absent; return 0; fi
    LOOKUP_ERR="$name: $(esc "$(tail -1 "$work/error")")"
    if [ "$attempt" = 1 ]; then sleep 5; fi
  done
  return 0
}

for file in "$@"; do
  [ -f "$file" ] || { printf -- '- %s: not a file\n' "$file" >> "$ERRORS_OUT"; continue; }
  url="$(tool yq -r '.spec.url' "$file" | sed 's#^oci://##')"
  tag="$(tool yq -r '.spec.ref.tag // ""' "$file")"
  digest="$(tool yq -r '.spec.ref.digest // ""' "$file")"
  verified="$(tool yq -r '.spec.verify != null' "$file")"
  reason="$(tool yq -r '.metadata.annotations["home-ops/chart-verify-exclusion-reason"] // ""' "$file")"
  if [ -n "$digest" ]; then ref="$url@$digest"; else ref="$url:$tag"; fi
  digest="${digest:--}"
  if [ "$verified" = true ]; then row skipped 'verify block present; discovery not applicable'; continue; fi
  case "$reason" in
    ''|unsigned) ;;
    keyed-unpinned|verifier-gap|unverifiable) row skipped "declared $reason; manual signing review"; continue ;;
    *) inconclusive "unknown exclusion reason: $(esc "$reason")"; continue ;;
  esac
  if [ "$digest" = - ]; then
    if [ -z "$tag" ]; then inconclusive 'no tag or digest pin'; continue; fi
    lookup resolve true tool oras resolve "$ref"
    case "$LOOKUP" in
      absent) inconclusive 'the tag does not exist'; continue ;;
      inconclusive) inconclusive "$LOOKUP_ERR"; continue ;;
    esac
    digest="$(tr -d '[:space:]' < "$work/response")"
  fi
  if ! printf '%s\n' "$digest" | grep -Eq '^sha256:[0-9a-f]{64}$'; then
    digest=-; inconclusive 'invalid or unsupported digest'; continue
  fi

  material=""; error=""
  for kind in sig att; do
    lookup "legacy .$kind tag" true tool oras manifest fetch --descriptor "$url:sha256-${digest#sha256:}.$kind"
    case "$LOOKUP" in
      present) material+="legacy-.$kind " ;;
      inconclusive) error="${error:-$LOOKUP_ERR}" ;;
    esac
  done
  lookup referrers false tool oras discover --depth 1 --format json "$url@$digest"
  if [ "$LOOKUP" = inconclusive ]; then
    error="${error:-$LOOKUP_ERR}"
  elif ! tool yq -p=json -e '(.referrers | tag) == "!!seq"' "$work/response" > /dev/null 2>&1; then
    error="${error:-invalid referrer response}"
  elif types="$(tool yq -p=json -r '.referrers[] | (.artifactType // "untyped") | sub("^$", "untyped")' "$work/response" 2> /dev/null)"; then
    while IFS= read -r type; do
      case "$type" in
        ''|application/spdx+json|application/vnd.cyclonedx+json) ;;
        *) material+="referrer:$(esc "$type") " ;;
      esac
    done <<< "$types"
  else
    error="${error:-invalid referrer descriptor}"
  fi
  if [ -n "$error" ]; then inconclusive "$error"; continue; fi
  if [ -n "$material" ]; then
    material="${material% }"
    row material-present "$material"
    printf -- "- \`%s\` (\`%s\`) carries signing-related or unknown material (%s). Review it under ADR-0003 before changing trust or the exclusion reason (\`%s\`).\n" \
      "$ref" "$digest" "$material" "$file" >> "$FINDINGS_OUT"
  else
    row unsigned 'no signing-related or unknown material discovered'
  fi
done
