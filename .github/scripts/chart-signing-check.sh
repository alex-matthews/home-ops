#!/usr/bin/env bash
# Chart signing check for sources without a verify block (ADR-0003, #2018).
#
# Discovery first, verification second. For each ocirepository.yaml given, the
# script takes the pinned digest, or resolves the pinned tag to one, then runs
# three lookups against that digest: the legacy signature tag, the legacy
# attestation tag, and the direct OCI referrers. Each lookup ends present,
# absent, or inconclusive; absent means the registry answered that the
# manifest does not exist, and nothing else. A source is "unsigned" only if
# all three are absent. Material that is present is classified with cosign,
# by digest, keylessly under any identity. A source recorded as signed with a
# static key (cert-manager) is checked three ways, each independently: under
# its published key with the recorded digest algorithm, under the key with
# SHA-256, and keylessly; a cosign result other than a clean pass or a clean
# mismatch is inconclusive, never a claim. With --mirror, the exact tag, with
# any leading "v" stripped, is resolved on the home-operations charts-mirror
# registry under the chart's own name, or under an alias from MIRROR_ALIASES;
# the mirror's inventory is read only to refuse a name it lists more than
# once. The registry also answers for packages the mirror has retired but
# still serves.
#
# Output: one TSV line per source on stdout (file, ref, digest, class, detail),
# plus one per mirror lookup. Findings and inconclusive checks are appended as
# Markdown bullets to the files named by FINDINGS_OUT and ERRORS_OUT. Exit 0
# unless the script itself fails, so the caller decides. Requires mise-managed
# cosign, oras, and yq, plus git and curl.
set -euo pipefail

MIRROR=0
if [ "${1:-}" = "--mirror" ]; then MIRROR=1; shift; fi
[ "$#" -gt 0 ] || { echo "usage: $0 [--mirror] FILE..." >&2; exit 64; }
: "${FINDINGS_OUT:=/dev/null}" "${ERRORS_OUT:=/dev/null}"

# Sources signed with a static key, recorded in #1894: file, key URL, recorded digest algorithm.
KEYED='kubernetes/apps/cert-manager/cert-manager/app/ocirepository.yaml https://cert-manager.io/public-keys/cert-manager-pubkey-2021-09-20.pem sha512'
# Mirror name overrides, "<chart>=<artifactName>", applied before the inventory is consulted.
MIRROR_ALIASES=''
MIRROR_REPO=https://github.com/home-operations/charts-mirror
MIRROR_REGISTRY=ghcr.io/home-operations/charts-mirror

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

tool() { mise exec -- "$@"; }
# One line, no Markdown or delimiter-sensitive characters, at most 160 characters.
esc() { printf '%s' "$1" | tr '\n\r\t' '   ' | tr -d '`<>[]()*_#|' | cut -c1-160; }
finding() { printf -- '- %s\n' "$1" >> "$FINDINGS_OUT"; }
inconclusive() { printf -- '- %s\n' "$1" >> "$ERRORS_OUT"; }
# The one registry answer that establishes absence: oras reporting the requested manifest as not found.
absent_text() { grep -Eq '^Error response from registry: failed to (find |resolve digest: ).*: not found$'; }

# lookup NAME CMD... -> LOOKUP=present|absent|inconclusive, LOOKUP_ERR; one retry on inconclusive. Always returns 0.
lookup() {
  local name=$1; shift
  local attempt err
  LOOKUP=inconclusive; LOOKUP_ERR=""
  for attempt in 1 2; do
    if err="$("$@" 2>&1 > /dev/null)"; then LOOKUP=present; LOOKUP_ERR=""; return 0; fi
    if printf '%s\n' "$err" | absent_text; then LOOKUP=absent; LOOKUP_ERR=""; return 0; fi
    LOOKUP_ERR="$name: $(esc "$(printf '%s' "$err" | tail -1)")"
    if [ "$attempt" = 1 ]; then sleep 5; fi
  done
  return 0
}

# verify NAME CMD... -> VERIFY=pass|mismatch|inconclusive; cosign's clean failure is a mismatch, anything else is not a result.
verify() {
  local name=$1; shift
  local err
  if err="$("$@" 2>&1 > /dev/null)"; then VERIFY=pass; return 0; fi
  if printf '%s' "$err" | grep -q 'no matching signatures\|no signatures found'; then VERIFY=mismatch; return 0; fi
  VERIFY=inconclusive; VERIFY_ERR="$name: $(esc "$(printf '%s' "$err" | tail -1)")"
  return 0
}

if [ "$MIRROR" = 1 ]; then
  if ! git clone -q --depth 1 "$MIRROR_REPO" "$work/mirror" 2> "$work/clone.err"; then
    inconclusive "charts-mirror inventory could not be read: $(esc "$(tail -1 "$work/clone.err")")"
    MIRROR=0
  fi
fi

for file in "$@"; do
  [ -f "$file" ] || { inconclusive "$file: not a file"; continue; }
  url="$(tool yq -r '.spec.url' "$file" | sed 's#^oci://##')"
  tag="$(tool yq -r '.spec.ref.tag // ""' "$file")"
  digest="$(tool yq -r '.spec.ref.digest // ""' "$file")"
  ref="$url:${tag:-$digest}"

  if [ -z "$digest" ] && [ -z "$tag" ]; then
    inconclusive "\`$url\` pins neither a tag nor a digest; not checked (\`$file\`)"
    printf '%s\t%s\t-\tinconclusive\tno pin\n' "$file" "$url"; continue
  fi
  if [ -z "$digest" ]; then
    reason=""
    for attempt in 1 2; do
      digest="$(tool oras resolve "$ref" 2> "$work/resolve.err" | tr -d '[:space:]')" && [ -n "$digest" ] && break
      digest=""
      if absent_text < "$work/resolve.err"; then reason="the tag does not exist"; break; fi
      reason="resolve: $(esc "$(tail -1 "$work/resolve.err")")"
      if [ "$attempt" = 1 ]; then sleep 5; fi
    done
    if [ -z "$digest" ]; then
      inconclusive "\`$ref\` could not be resolved: $reason (\`$file\`)"
      printf '%s\t%s\t-\tinconclusive\tresolve\n' "$file" "$ref"; continue
    fi
  fi
  hex="${digest#sha256:}"

  # Discover.
  state=""; material=""
  lookup "legacy signature tag" tool oras manifest fetch --descriptor "$url:sha256-$hex.sig"
  [ "$LOOKUP" = present ] && material+="legacy-signature "
  [ "$LOOKUP" = inconclusive ] && state="$LOOKUP_ERR"
  lookup "legacy attestation tag" tool oras manifest fetch --descriptor "$url:sha256-$hex.att"
  [ "$LOOKUP" = present ] && material+="legacy-attestation "
  [ "$LOOKUP" = inconclusive ] && state="${state:-$LOOKUP_ERR}"
  count=""
  for attempt in 1 2; do
    if json="$(tool oras discover --depth 1 --format json "$url@$digest" 2> "$work/discover.err")"; then
      count="$(printf '%s' "$json" | tool yq -r '.referrers | length')"
      types="$(printf '%s' "$json" | tool yq -r '[.referrers[]?.artifactType // "untyped"] | join(",")')"
      break
    fi
    if [ "$attempt" = 1 ]; then sleep 5; fi
  done
  if [ -z "$count" ]; then
    state="${state:-referrers: $(esc "$(tail -1 "$work/discover.err")")}"
  elif [ "$count" != 0 ]; then
    material+="referrers:$types "
  fi
  if [ -n "$state" ]; then
    inconclusive "\`$ref\` (\`$digest\`): $state (\`$file\`)"
    printf '%s\t%s\t%s\tinconclusive\t%s\n' "$file" "$ref" "$digest" "$state"; continue
  fi

  # Classify.
  keyed="$(printf '%s\n' "$KEYED" | awk -v f="$file" '$1 == f { print $2, $3 }')"
  class=""; detail=""
  if [ -n "$keyed" ]; then
    keyurl="${keyed%% *}"; algo="${keyed##* }"
    if [ -z "$material" ]; then
      class="keyed-gone"; detail="recorded static-key signature is no longer present"
      finding "\`$ref\` (\`$digest\`) no longer carries the static-key signature recorded in #1894 (\`$file\`)."
    elif ! curl -fsSL -o "$work/key.pem" "$keyurl" 2> "$work/key.err"; then
      state="published key could not be fetched: $(esc "$(tail -1 "$work/key.err")")"
    else
      verify "keyed $algo" tool cosign verify --key "$work/key.pem" --signature-digest-algorithm "$algo" --insecure-ignore-tlog "$url@$digest"; recorded=$VERIFY
      verify "keyed sha256" tool cosign verify --key "$work/key.pem" --insecure-ignore-tlog "$url@$digest"; readable=$VERIFY
      verify "keyless" tool cosign verify --certificate-identity-regexp '.*' --certificate-oidc-issuer-regexp '.*' "$url@$digest"; keyless=$VERIFY
      if [ "$recorded" = inconclusive ] || [ "$readable" = inconclusive ] || [ "$keyless" = inconclusive ]; then
        state="$VERIFY_ERR"
      elif [ "$readable" = pass ]; then
        class="keyed-sha256"; detail="verifies under the published key with SHA-256; Flux's keyed verifier can read it"
        finding "\`$ref\` (\`$digest\`) verifies under its published key with SHA-256; re-validate and add a keyed verify block (\`$file\`)."
      elif [ "$keyless" = pass ]; then
        class="keyless-added"; detail="keyless signature verifies alongside the static key ($material)"
        finding "\`$ref\` (\`$digest\`) carries a keyless signature that verifies; re-validate the identity and add a verify block (\`$file\`)."
      elif [ "$recorded" = pass ]; then
        class="keyed-known"; detail="verifies under the published key with $algo only, as recorded ($material)"
      else
        class="keyed-changed"; detail="signing material present ($material) but the recorded key no longer verifies it"
        finding "\`$ref\` (\`$digest\`): the recorded static key no longer verifies this artifact; the signing material changed ($(esc "$material")) (\`$file\`)."
      fi
    fi
  elif [ -z "$material" ]; then
    class="unsigned"; detail="no signature tag, no attestation tag, no direct referrers"
  else
    verify "keyless" tool cosign verify --certificate-identity-regexp '.*' --certificate-oidc-issuer-regexp '.*' "$url@$digest"
    case $VERIFY in
      pass) class="keyless-verified"; detail="keyless signature verifies under some identity ($material)"
            finding "\`$ref\` (\`$digest\`) carries a keyless signature that verifies; re-validate the identity and add a verify block (\`$file\`)." ;;
      mismatch) class="material-present"; detail="signing material present ($material) but not keyless-verifiable"
            finding "\`$ref\` (\`$digest\`) carries signing material this check cannot verify keylessly ($(esc "$material")); look at it (\`$file\`)." ;;
      *) state="$VERIFY_ERR" ;;
    esac
  fi
  if [ -n "$state" ]; then
    inconclusive "\`$ref\` (\`$digest\`): $state (\`$file\`)"
    printf '%s\t%s\t%s\tinconclusive\t%s\n' "$file" "$ref" "$digest" "$state"; continue
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$file" "$ref" "$digest" "$class" "$detail"

  # Mirror.
  [ "$MIRROR" = 1 ] || continue
  if [ -z "$tag" ]; then
    printf '%s\t%s\t%s\tmirror-skipped\tdigest pin, no tag to look up\n' "$file" "$ref" "$digest"; continue
  fi
  chart="${url##*/}"
  artifact="$(printf '%s\n' "$MIRROR_ALIASES" | tr ' ' '\n' | awk -F= -v c="$chart" '$1 == c { print $2 }')"
  if [ -z "$artifact" ]; then
    matches="$( { grep -lx "artifactName: $chart" "$work"/mirror/apps/*/metadata.yaml 2> /dev/null || true; } | wc -l | tr -d ' ')"
    case "$matches" in
      0) artifact="$chart" ;;
      1) artifact="$chart" ;;
      *) inconclusive "charts-mirror lists \`$chart\` more than once; add a mirror alias (\`$file\`)"
         printf '%s\t%s\t%s\tinconclusive\tmirror: ambiguous\n' "$file" "$ref" "$digest"; continue ;;
    esac
  fi
  mirror_ref="$MIRROR_REGISTRY/$artifact:${tag#v}"
  lookup "mirror tag" tool oras resolve "$mirror_ref"
  case $LOOKUP in
    present) printf '%s\t%s\t%s\tmirror-present\t%s\n' "$file" "$ref" "$digest" "$mirror_ref"
             finding "charts-mirror serves \`$mirror_ref\`, a candidate for a mirror-custody identity (\`$file\`)." ;;
    absent)  printf '%s\t%s\t%s\tmirror-absent\t%s not published\n' "$file" "$ref" "$digest" "$mirror_ref" ;;
    *)       inconclusive "\`$mirror_ref\` could not be resolved: $LOOKUP_ERR (\`$file\`)"
             printf '%s\t%s\t%s\tinconclusive\tmirror\n' "$file" "$ref" "$digest" ;;
  esac
done
exit 0
