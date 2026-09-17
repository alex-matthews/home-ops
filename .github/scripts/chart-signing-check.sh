#!/usr/bin/env bash
# Observe excluded chart sources and compare with their manifest declarations (#2145).
# Discover legacy signature/attestation tags and direct OCI referrers at the pinned
# digest. Verify certificates under their own identities; for verifier-gap only,
# try the declared committed key with SHA-256 and SHA-512. Unknowns stay inconclusive.
# Findings/errors go to FINDINGS_OUT/ERRORS_OUT; stdout is TSV (file, ref, digest,
# result, detail). Exit 0 unless the script itself fails; the caller handles findings.
# CHART_SIGNING_TOOLS and CHART_SIGNING_KEYS allow offline fixtures.
set -euo pipefail

[ "$#" -gt 0 ] || { echo "usage: $0 FILE..." >&2; exit 64; }
: "${FINDINGS_OUT:=/dev/null}" "${ERRORS_OUT:=/dev/null}"
: "${CHART_SIGNING_KEYS:=.github/keys}"

ANNOTATION_REASON=home-ops/chart-verify-exclusion-reason
ANNOTATION_KEY=home-ops/chart-verify-key-fingerprint
REASONS='unsigned keyed-unpinned verifier-gap unverifiable'
# Referrer types that are not signing material and are ignored.
IGNORED_REFERRER_TYPES='application/spdx+json application/vnd.cyclonedx+json application/vnd.in-toto+json'

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

tool() {
  if [ -n "${CHART_SIGNING_TOOLS:-}" ]; then "$CHART_SIGNING_TOOLS/$1" "${@:2}"; else mise exec -- "$@"; fi
}
# One line, no Markdown or delimiter-sensitive characters, at most 160 characters.
esc() { printf '%s' "$1" | tr '\n\r\t' '   ' | tr -d '`<>[]()*_#|' | cut -c1-160; }
finding() { printf -- '- %s\n' "$1" >> "$FINDINGS_OUT"; }
inconclusive() { printf -- '- %s\n' "$1" >> "$ERRORS_OUT"; }
row() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }
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

# verify NAME CMD... -> VERIFY=pass|mismatch|inconclusive. Only a refusal cosign 3.1 was observed to emit for a
# wrong key, a wrong algorithm or a wrong identity counts as a mismatch, matched on the last line; a generic
# prefix such as "no matching signatures" wrapping an outage is not recognised and stays inconclusive.
verify() {
  local name=$1; shift
  local err
  VERIFY_ERR=""
  if err="$("$@" 2>&1 > /dev/null)"; then VERIFY=pass; return 0; fi
  if printf '%s' "$err" | tail -1 | grep -Eq 'ecdsa: Invalid IEEE_P1363 encoded bytes$|crypto/rsa: verification error$|none of the expected identities matched what was in the certificate, got subjects \[[^]]*\]$|no matching CertificateIdentity found, last error: expected (SAN|issuer) value "[^"]*", got "[^"]*"$|accepted signatures do not match threshold, Found: [0-9]+, Expected [0-9]+$|expected key signature, not certificate$'; then
    VERIFY=mismatch; return 0
  fi
  VERIFY=inconclusive; VERIFY_ERR="$name: $(esc "$(printf '%s' "$err" | tail -1)")"
  return 0
}

# fetch NAME FILE CMD... -> FETCH=ok|inconclusive with stdout in FILE; one retry.
fetch() {
  local name=$1 out=$2; shift 2
  local attempt
  FETCH=inconclusive; FETCH_ERR=""
  for attempt in 1 2; do
    if "$@" > "$out" 2> "$work/fetch.err"; then FETCH=ok; return 0; fi
    FETCH_ERR="$name: $(esc "$(tail -1 "$work/fetch.err")")"
    if [ "$attempt" = 1 ]; then sleep 5; fi
  done
  return 0
}

# Committed keys: "<fingerprint-hex> <path>" per line.
KEYS=""
for k in "$CHART_SIGNING_KEYS"/*.pem; do
  [ -f "$k" ] || continue
  fp="$(openssl pkey -pubin -in "$k" -outform DER 2> /dev/null | openssl dgst -sha256 | awk '{print $NF}')"
  [ -n "$fp" ] || { inconclusive "committed key \`$k\` is not a readable public key"; continue; }
  KEYS+="$fp $k"$'\n'
done
key_path() { printf '%s' "$KEYS" | awk -v f="$1" '$1 == f { print $2 }'; }
hint_to_hex() { printf '%s' "$1" | base64 -d 2> /dev/null | od -An -tx1 | tr -d ' \n'; }

# cert_identity FILE -> CERT_SAN, CERT_ISSUER (empty when unreadable). PEM or DER.
cert_identity() {
  local f=$1 text
  CERT_SAN=""; CERT_ISSUER=""
  text="$(openssl x509 -in "$f" -noout -text 2> /dev/null || openssl x509 -inform DER -in "$f" -noout -text 2> /dev/null)" || true
  [ -n "$text" ] || return 0
  CERT_SAN="$(printf '%s\n' "$text" | grep -o 'URI:[^,[:space:]]*' | head -1 | sed 's/^URI://')"
  CERT_ISSUER="$(printf '%s\n' "$text" | grep -A1 '1\.3\.6\.1\.4\.1\.57264\.1\.1:' | tail -1 | sed 's/^[[:space:]]*//; s/^[^h]*http/http/')"
  return 0
}

for file in "$@"; do
  [ -f "$file" ] || { inconclusive "$file: not a file"; continue; }
  url="$(tool yq -r '.spec.url' "$file" | sed 's#^oci://##')"
  tag="$(tool yq -r '.spec.ref.tag // ""' "$file")"
  digest="$(tool yq -r '.spec.ref.digest // ""' "$file")"
  provider="$(tool yq -r '.spec.verify.provider // ""' "$file")"
  reason="$(tool yq -r ".metadata.annotations[\"$ANNOTATION_REASON\"] // \"\"" "$file")"
  declared_fp="$(tool yq -r ".metadata.annotations[\"$ANNOTATION_KEY\"] // \"\"" "$file" | sed 's/^sha256://')"
  ref="$url:${tag:-$digest}"

  if [ -z "$digest" ] && [ -z "$tag" ]; then
    inconclusive "\`$url\` pins neither a tag nor a digest; not checked (\`$file\`)"
    row "$file" "$url" - inconclusive "no pin"; continue
  fi

  # Verified sources are checked under their pinned identity by the PR workflow.
  if [ -n "$provider" ]; then
    row "$file" "$ref" - verified "verify block present"; continue
  fi
  # Missing declarations still get discovery output to help choose a reason.
  if [ -n "$reason" ] && ! printf '%s\n' "$REASONS" | tr ' ' '\n' | grep -Fqx -- "$reason"; then
    inconclusive "\`$ref\` declares the unknown exclusion reason \`$(esc "$reason")\` (\`$file\`)"
    row "$file" "$ref" - inconclusive "unknown exclusion reason"; continue
  fi
  declared_key=""
  if [ "$reason" = verifier-gap ]; then
    declared_key="$(key_path "$declared_fp")"
    if [ -z "$declared_key" ]; then
      inconclusive "\`$ref\` names the key fingerprint \`$declared_fp\` but no key under \`$CHART_SIGNING_KEYS\` matches it (\`$file\`)"
      row "$file" "$ref" - inconclusive "declared key not committed"; continue
    fi
  fi

  # Resolve.
  if [ -z "$digest" ]; then
    resolve_reason=""
    for attempt in 1 2; do
      digest="$(tool oras resolve "$ref" 2> "$work/resolve.err" | tr -d '[:space:]')" && [ -n "$digest" ] && break
      digest=""
      if absent_text < "$work/resolve.err"; then resolve_reason="the tag does not exist"; break; fi
      resolve_reason="resolve: $(esc "$(tail -1 "$work/resolve.err")")"
      if [ "$attempt" = 1 ]; then sleep 5; fi
    done
    if [ -z "$digest" ]; then
      inconclusive "\`$ref\` could not be resolved: $resolve_reason (\`$file\`)"
      row "$file" "$ref" - inconclusive "resolve"; continue
    fi
  fi
  hex="${digest#sha256:}"

  # Discover.
  state=""; material=""
  lookup "legacy signature tag" tool oras manifest fetch --descriptor "$url:sha256-$hex.sig"
  legacy_sig=$LOOKUP; [ "$LOOKUP" = present ] && material+="legacy-signature "
  [ "$LOOKUP" = inconclusive ] && state="$LOOKUP_ERR"
  lookup "legacy attestation tag" tool oras manifest fetch --descriptor "$url:sha256-$hex.att"
  legacy_att=$LOOKUP; [ "$LOOKUP" = present ] && material+="legacy-attestation "
  [ "$LOOKUP" = inconclusive ] && state="${state:-$LOOKUP_ERR}"
  referrers=""
  fetch "referrers" "$work/discover.json" tool oras discover --depth 1 --format json "$url@$digest"
  if [ "$FETCH" = ok ]; then
    referrers="$(tool yq -r '.referrers[]? | .digest + " " + (.artifactType // "untyped")' "$work/discover.json")"
    [ -n "$referrers" ] && material+="referrers:$(printf '%s\n' "$referrers" | awk '{print $2}' | paste -sd, -) "
  else
    state="${state:-$FETCH_ERR}"
  fi
  if [ -n "$state" ]; then
    inconclusive "\`$ref\` (\`$digest\`): $state (\`$file\`)"
    row "$file" "$ref" "$digest" inconclusive "$state"; continue
  fi

  # Parse: signature certificates to $work/certs/N, keyed hints to $keyed_hints, keyed legacy layers to
  # $keyed_legacy. Attestations (.att) are parsed for shape only and counted in $att_layers: they are not
  # signatures the verifier reads, so they are never verified here.
  rm -rf "$work/certs"; mkdir -p "$work/certs"; ncert=0; keyed_hints=""; keyed_legacy=0; att_layers=0
  parse_legacy() { # kind manifest-file -> certificates and keyed layers, or a recorded inconclusive
    local kind=$1 file=$2 n i cert
    n="$(tool yq -r '[.layers[]? | select(.mediaType == "application/vnd.dev.cosign.simplesigning.v1+json" or .mediaType == "application/vnd.dsse.envelope.v1+json")] | length' "$file")"
    if [ "$n" = 0 ]; then state="${state:-legacy $kind manifest carries no signature layer this check recognises}"; return 0; fi
    for i in $(seq 0 $((n - 1))); do
      cert="$(tool yq -r "[.layers[]? | select(.mediaType == \"application/vnd.dev.cosign.simplesigning.v1+json\" or .mediaType == \"application/vnd.dsse.envelope.v1+json\")][$i].annotations[\"dev.sigstore.cosign/certificate\"] // \"\"" "$file")"
      if [ "$kind" = att ]; then
        att_layers=$((att_layers + 1))
      elif [ -n "$cert" ]; then
        printf '%s\n' "$cert" > "$work/certs/$ncert"; ncert=$((ncert + 1))
      else
        keyed_legacy=1
      fi
    done
  }
  for kind in sig att; do
    [ "$( [ "$kind" = sig ] && echo "$legacy_sig" || echo "$legacy_att")" = present ] || continue
    fetch "legacy $kind manifest" "$work/legacy-$kind.json" tool oras manifest fetch "$url:sha256-$hex.$kind"
    if [ "$FETCH" = ok ]; then parse_legacy "$kind" "$work/legacy-$kind.json"; else state="${state:-$FETCH_ERR}"; fi
  done
  while read -r rdigest rtype; do
    [ -n "$rdigest" ] || continue
    if printf '%s\n' "$IGNORED_REFERRER_TYPES" | tr ' ' '\n' | grep -Fqx -- "$rtype"; then continue; fi
    fetch "referrer $rtype" "$work/referrer.json" tool oras manifest fetch "$url@$rdigest"
    [ "$FETCH" = ok ] || { state="${state:-$FETCH_ERR}"; continue; }
    bundle_layer="$(tool yq -r '[.layers[] | select(.mediaType | test("^application/vnd\\.dev\\.sigstore\\.bundle")) | .digest] | .[0] // ""' "$work/referrer.json")"
    if [ -z "$bundle_layer" ]; then
      state="${state:-referrer $(esc "$rtype") ($rdigest) is not a signing bundle this check recognises}"; continue
    fi
    fetch "bundle blob" "$work/bundle.json" tool oras blob fetch --output - "$url@$bundle_layer"
    [ "$FETCH" = ok ] || { state="${state:-$FETCH_ERR}"; continue; }
    raw="$(tool yq -r '.verificationMaterial.certificate.rawBytes // ""' "$work/bundle.json")"
    hint="$(tool yq -r '.verificationMaterial.publicKey.hint // ""' "$work/bundle.json")"
    if [ -n "$raw" ]; then
      printf '%s' "$raw" | base64 -d > "$work/certs/$ncert" 2> /dev/null && ncert=$((ncert + 1)) || state="${state:-bundle certificate could not be decoded}"
    elif [ -n "$hint" ]; then
      keyed_hints+="$(hint_to_hex "$hint") "
    else
      state="${state:-bundle at $rdigest carries neither a certificate nor a public-key hint}"
    fi
  done <<< "$referrers"
  if [ -n "$state" ]; then
    inconclusive "\`$ref\` (\`$digest\`): $state (\`$file\`)"
    row "$file" "$ref" "$digest" inconclusive "$state"; continue
  fi

  # Verify certificates under their own exact identity.
  keyless_pass=""; keyless_mismatch=0
  for c in "$work"/certs/*; do
    [ -f "$c" ] || continue
    cert_identity "$c"
    if [ -z "$CERT_SAN" ] || [ -z "$CERT_ISSUER" ]; then state="${state:-a certificate in the signing material could not be read}"; continue; fi
    verify "keyless $CERT_SAN" tool cosign verify --certificate-identity "$CERT_SAN" --certificate-oidc-issuer "$CERT_ISSUER" "$url@$digest"
    case $VERIFY in
      pass) keyless_pass="${keyless_pass:-$CERT_SAN}" ;;
      mismatch) keyless_mismatch=1 ;;
      *) state="${state:-$VERIFY_ERR}" ;;
    esac
  done
  # Only a verifier-gap declaration authorizes a key for this source.
  keyed_present=0; keyed_sha256=""; keyed_sha512=""
  [ -n "$keyed_hints" ] || [ "$keyed_legacy" = 1 ] && keyed_present=1
  if [ "$keyed_present" = 1 ] && [ -n "$declared_key" ]; then
    verify "keyed sha256 $declared_fp" tool cosign verify --key "$declared_key" --insecure-ignore-tlog "$url@$digest"
    case $VERIFY in
      pass) keyed_sha256="$declared_fp" ;;
      inconclusive) state="${state:-$VERIFY_ERR}" ;;
      mismatch)
        verify "keyed sha512 $declared_fp" tool cosign verify --key "$declared_key" --signature-digest-algorithm sha512 --insecure-ignore-tlog "$url@$digest"
        case $VERIFY in pass) keyed_sha512="$declared_fp" ;; inconclusive) state="${state:-$VERIFY_ERR}" ;; esac ;;
    esac
  fi
  if [ -n "$state" ]; then
    inconclusive "\`$ref\` (\`$digest\`): $state (\`$file\`)"
    row "$file" "$ref" "$digest" inconclusive "$state"; continue
  fi

  # Observe, a passing verification first.
  if [ -n "$keyless_pass" ]; then
    observed=keyless-verifies; detail="keyless signature verifies under $keyless_pass ($material)"
  elif [ -n "$keyed_sha256" ]; then
    observed=keyed-verifies; detail="verifies under committed key $keyed_sha256 with SHA-256 ($material)"
  elif [ -n "$keyed_sha512" ]; then
    observed=verifier-gap; detail="verifies under committed key $keyed_sha512 with SHA-512 only ($material)"
  elif [ "$keyed_present" = 1 ] && [ -n "$declared_key" ]; then
    observed=key-mismatch; detail="keyed signing material present but committed key $declared_fp does not verify it ($material)"
  elif [ "$keyed_present" = 1 ]; then
    hints="${keyed_hints%% }"; observed=keyed-unpinned; detail="keyed signing material present (${hints:-legacy layer}) and no key is declared for this source ($material)"
  elif [ "$ncert" -gt 0 ] && [ "$keyless_mismatch" = 1 ]; then
    observed=unverifiable; detail="certificate-based signing material is refused under its own identity ($material)"
  elif [ "$att_layers" -gt 0 ]; then
    observed=unverifiable; detail="attestation-only material, which is not a signature the verifier reads ($material)"
  elif [ -z "$material" ]; then
    observed=unsigned; detail="no signature tag, no attestation tag, no direct referrers"
  else
    observed=unsigned; detail="referrers present but none is signing material ($material)"
  fi

  # Compare with the declared reason.
  if [ -z "$reason" ]; then
    inconclusive "\`$ref\` (\`$digest\`) has neither a verify block nor a \`$ANNOTATION_REASON\` annotation; observed \`$observed\`: $(esc "$detail") (\`$file\`)"
    row "$file" "$ref" "$digest" inconclusive "no exclusion reason declared; observed $observed: $detail"; continue
  fi
  same=0
  if [ "$observed" = "$reason" ]; then
    same=1
    [ "$observed" = verifier-gap ] && [ "$keyed_sha512" != "$declared_fp" ] && same=0
  fi
  row "$file" "$ref" "$digest" "$observed" "declared $reason; $detail"
  if [ "$same" = 0 ]; then
    case $observed in
      keyless-verifies) finding "\`$ref\` (\`$digest\`) carries a keyless signature that verifies under \`$(esc "$keyless_pass")\`; declared \`$reason\`. Re-validate the identity under ADR-0003 and add a verify block (\`$file\`)." ;;
      keyed-verifies) finding "\`$ref\` (\`$digest\`) verifies under the committed key \`$keyed_sha256\` with SHA-256, which the deployed verifier reads; declared \`$reason\`. Re-validate and add a keyed verify block (\`$file\`)." ;;
      verifier-gap) finding "\`$ref\` (\`$digest\`) verifies under the committed key \`$keyed_sha512\` with SHA-512 only; declared \`$reason\` with key \`$declared_fp\`. Correct the declaration (\`$file\`)." ;;
      key-mismatch) finding "\`$ref\` (\`$digest\`): the committed key \`$declared_fp\` no longer verifies this artifact; the signing material changed ($(esc "$material")) (\`$file\`)." ;;
      keyed-unpinned) finding "\`$ref\` (\`$digest\`) carries keyed signing material with no key declared for this source; declared \`$reason\`. Look for a published key, or declare \`keyed-unpinned\` (\`$file\`)." ;;
      unverifiable) finding "\`$ref\` (\`$digest\`) carries signing material nothing here can verify ($(esc "$detail")); declared \`$reason\`. Look at it, or declare \`unverifiable\` (\`$file\`)." ;;
      unsigned) finding "\`$ref\` (\`$digest\`) carries no signing material; declared \`$reason\`, so the signature recorded has disappeared (\`$file\`)." ;;
    esac
  fi

done
exit 0
