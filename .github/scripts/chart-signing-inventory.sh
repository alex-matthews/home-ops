#!/usr/bin/env bash
# Chart signing inventory (ADR-0003, #2145). Offline: yq only.
#
# Prints the register of chart sources derived from the manifests: every
# OCIRepository under kubernetes/, verified sources with the identities their
# verify blocks pin, excluded sources with the reason their annotation
# declares. This is the register; nothing else is maintained by hand.
#
# usage: chart-signing-inventory.sh [--tsv]
set -euo pipefail

ANNOTATION_REASON=home-ops/chart-verify-exclusion-reason
# Recognize the configured mirror signer offline, not the registry URL.
export MIRROR_ISSUER='^https://token\.actions\.githubusercontent\.com$'
export MIRROR_SUBJECT='^https://github\.com/home-operations/charts-mirror/\.github/workflows/app-builder\.yaml@refs/heads/main$'
tool() {
  if [ -n "${CHART_SIGNING_TOOLS:-}" ]; then "$CHART_SIGNING_TOOLS/$1" "${@:2}"; else mise exec -- "$@"; fi
}

rows="$(for file in $(find kubernetes -name ocirepository.yaml | sort); do
  tool yq -o=json -I=0 "[\"$file\", .spec.url, (.spec.ref.tag // .spec.ref.digest // \"\"), (.spec.verify != null), (.metadata.annotations[\"$ANNOTATION_REASON\"] // \"undeclared\"), ([.spec.verify.matchOIDCIdentity[]?.subject] | join(\" \")), (.spec.verify.provider == \"cosign\" and ([.spec.verify.matchOIDCIdentity[]? | select(.issuer == strenv(MIRROR_ISSUER) and .subject == strenv(MIRROR_SUBJECT))] | length > 0))] | @tsv" -r "$file"
done | awk -F'\t' 'BEGIN { OFS = "\t" } { if ($4 == "true") print $1, $2, $3, "verified", $6, ($7 == "true" ? "mirror custody" : ""); else print $1, $2, $3, $5, "", "" }')"

if [ "${1:-}" = "--tsv" ]; then printf '%s\n' "$rows"; exit 0; fi

verified="$(printf '%s\n' "$rows" | awk -F'\t' '$4 == "verified"' | wc -l | tr -d ' ')"
excluded="$(printf '%s\n' "$rows" | awk -F'\t' '$4 != "verified"' | wc -l | tr -d ' ')"
echo "## Chart sources: $verified verified, $excluded excluded"
echo
echo "### Excluded, by declared reason"
echo
echo "| Source | Pin | Reason | Discovery |"
echo "| --- | --- | --- | --- |"
printf '%s\n' "$rows" | awk -F'\t' '$4 != "verified" { printf "| `%s` | `%s` | %s | %s |\n", $2, $3, $4, ($4 == "unsigned" ? "weekly + PR" : "manual review") }'
echo
echo "### Verified, by pinned identity"
echo
echo "| Source | Pin | Verification | Identity |"
echo "| --- | --- | --- | --- |"
printf '%s\n' "$rows" | awk -F'\t' '$4 == "verified" { printf "| `%s` | `%s` | verified%s | `%s` |\n", $2, $3, ($6 == "" ? "" : " — " $6), $5 }'
