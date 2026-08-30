# ADR-0003: Helm Chart Source Verification and Publisher Trust Classes

- **Status:** Accepted
- **Date:** 2026-08-07
- **Related:** [Issue #1893](https://github.com/alex-matthews/home-ops/issues/1893) (artifact trust umbrella), [Issue #1894](https://github.com/alex-matthews/home-ops/issues/1894) (implementation)

## Context and Problem Statement

Every workload chart reaches this cluster through one of 65 Flux
`OCIRepository` sources, all pinned by mutable tag with no signature
verification. Flux supports Cosign verification on OCI sources, including
keyless verification constrained to a certificate identity via
`matchOIDCIdentity`. The question is not only whether to enable it, but
which signer identities this repository trusts, how narrowly they can
actually be expressed, and how the different signatures on offer differ in
what they prove.

End-to-end verification of all 42 unique pinned artifacts (2026-08-07:
digest resolution, signature discovery via both legacy tags and OCI
referrer bundles, and a full `cosign verify` under a pinned identity for
every candidate) found **27 artifacts verifiable, covering 50 of the 65
sources**, across 13 distinct GitHub-Actions signing identities. One
artifact (cert-manager) is signed with a SHA-512 static key that the
deployed source-controller cannot verify — its public-key verifier
hardcodes SHA-256 — and 14 artifacts are unsigned.

Three structural facts shape the policy more than any preference:

- Three identities — covering 30 of the 50 verifiable sources — sign from
  public **reusable workflows** (`workflow_call`). For those, the Fulcio
  certificate subject identifies the called workflow file and ref, not the
  calling repository, and any repository can call a public reusable
  workflow. Flux matches only certificate issuer and subject, so the policy
  cannot pin the caller. Signatures are digest-bound but not
  repository-bound, so a signature minted anywhere is portable to any
  registry path the attacker can write to.
- Six identities sign from branch refs (`main`/`master`), not tagged
  releases. A tagged-ref-only policy is unachievable; the narrowest
  expressible identity varies per publisher.
- Verification runs only when the fetched digest or the source spec
  changes, and a failure leaves the previously stored artifact in place
  (confirmed in the deployed controller's source). The failure mode is a
  frozen chart update, not a workload outage — expected, and to be
  confirmed live before broad rollout.

Verification is one layer of a larger artifact trust model (source
authentication only). It does not verify the container images a chart
selects, does not evaluate provenance or content, and does not make a
mutable tag immutable — it narrows who can sign replacement bytes, not
whether bytes can be replaced.

## Decision Drivers

- Changes reach the cluster only through Git; verification failure must
  degrade to an upgrade freeze, never an outage — and the rollout must
  abort if observed behaviour differs.
- No new operators, CRDs, or admission surface for this layer.
- Claims must be evidence-bound: every trusted identity derives from a
  certificate or key cryptographically validated against the pinned
  artifact, not from publisher documentation.
- Differences in what a signature proves must be visible in the policy, not
  flattened into one "verified" state.
- Bootstrap-critical Flux sources must not be the proving ground.

## Considered Options

1. **No verification** — rejected. Identity-bound verification raises the
   cost of a registry-side artifact swap for three-quarters of the estate.
   The manifest change is cheap; the real costs (correlated upgrade
   freezes, Sigstore availability as a soft update dependency, signer
   rotation response, eventual CI guarding) are operational and accepted.
2. **Unconstrained keyless verification** (`provider: cosign` with no
   identity matcher) — rejected. It accepts any signature rooted in the
   public Sigstore infrastructure, including an attacker's own.
3. **Identity-bound verification with publisher trust classes** — chosen.
   Verify only where an identity has been validated against the artifact,
   with the narrowest expressible matcher, and classify what each identity
   proves.
4. **Organisation-wide subject patterns** — rejected. They delegate signing
   authority to every repository, workflow, and ref in an org and mask
   signer changes that should be reviewed.
5. **Image-signature admission control** — out of scope for this layer.

## Decision

Adopt identity-bound Cosign verification on eligible `OCIRepository` chart
sources, under the following policy.

**Publisher trust classes.** Every chart source is classified as one of:

- _Direct upstream workflow identity_: signed by a top-level workflow in
  the publisher's own repository, triggered by maintainer action (push,
  tag, release, or dispatch). The certificate binds publisher repository,
  workflow, and ref. Strongest class this mechanism can express.
- _Reusable-workflow custody_: signed by a public `workflow_call` workflow.
  The certificate binds the called workflow file and ref only; the caller
  is not expressible in Flux. Weaker: an attacker with write access to the
  exact registry path could obtain an accepted signature by calling the
  public workflow from their own repository. Accepted, with that residual
  risk recorded, because the registry-write requirement still excludes
  every signer outside the workflow.
- _Mirror custody_: reusable-workflow custody plus repackaging of
  third-party content (the home-operations charts-mirror). A valid
  signature proves the mirror pipeline published the bytes — the mirror
  does not verify upstream signatures or provenance, so upstream authorship
  is not established. Accepted on its own terms: pinning the pipeline
  identity still excludes all other signers, which is materially better
  than no verification. Never described as upstream authenticity.
- _Signed, not verifiable by deployed Flux_: signatures the verifier cannot
  process (cert-manager's SHA-512 static key against Flux's hardcoded
  SHA-256 public-key verifier). Excluded, tracked for Flux or publisher
  movement.
- _Unsigned / unverifiable_: everything else. Documented as excluded, with
  no implication that exclusion is safe.

**Identity policy.** Keyless verification always carries
`matchOIDCIdentity`. Issuer and subject regexes are anchored (`^...$`). The
subject pins the exact repository, workflow filename, and ref observed in a
certificate validated against the pinned artifact — as narrow as the
publisher's actual signing practice supports. Version components in tag
refs use strict patterns (for example `v[0-9]+\.[0-9]+\.[0-9]+$`), never
loose character classes. Should a keyed source become verifiable, the same
rule applies to its key: pinned, and validated against the artifact before
adoption. The observed identity for each verified source is recorded in
implementation issue #1894 at adoption time, and each trusted workflow is
checked for `workflow_call` reachability and untrusted-trigger paths before
its class is assigned.

The canonical shape (identity from a real observed certificate):

```yaml
verify:
    provider: cosign
    matchOIDCIdentity:
        - issuer: "^https://token\\.actions\\.githubusercontent\\.com$"
          subject: "^https://github\\.com/controlplaneio-fluxcd/charts/\\.github/workflows/release\\.yml@refs/tags/v[0-9]+\\.[0-9]+\\.[0-9]+$"
```

**Accepted residual risks**, recorded here so they are not rediscovered:

- Reusable-workflow and mirror classes prove "signed by this workflow file
  at this ref, from some caller", per above.
- Tags remain mutable; verification constrains the signer of replacement
  bytes, not their existence.
- Keyless verification makes Sigstore availability a soft dependency of
  chart _updates_ (never of running workloads); stable verified revisions
  are not re-verified.
- Most eligible artifacts carry cosign v3 bundle signatures (DSSE
  envelopes). These verify under the cosign CLI major that the deployed
  Flux vendors, but live acceptance by the deployed source-controller is a
  pilot gate, not an assumption.

**Rollout principle.** Staged from low-value sources to bootstrap-critical
Flux sources, which verify last; no phase extends until the previous
phase's evidence is in. Phase composition, gates, and per-source records
are delivery state and live in implementation issue #1894. **Abort:** if
verification failure is observed to discard a stored artifact, degrade a
running release, or block unrelated reconciliation, stop and revisit this
ADR before any extension.

**Exceptions and removal.** Removing or loosening a `verify` block requires
a pull request citing the re-observed certificate identity and the reason.
A source whose publisher stops signing moves back to the unsigned class in
the exclusions inventory rather than being silently dropped.

## Consequences

- 50 of 65 sources become verifiable; 15 remain excluded (14 unsigned, one
  signed-but-incompatible). The exclusions inventory is the honest
  statement of that boundary.
- Coverage concentrates in identities: one reusable-workflow identity
  covers 23 sources (bjw-s app-template). A signer change there freezes
  chart updates for all of them at once — surfaced by the existing Flux →
  Alertmanager alert path, resolved by a reviewed policy update.
- Renovate keeps working unchanged (it edits only `spec.ref.tag`), but
  signer drift is invisible pre-merge and surfaces as a post-merge
  verification failure. A pre-merge CI signature guard is deliberate
  follow-up work, not part of this layer.
- Implementation issue #1894 is bounded: complete when every source
  eligible at execution time is verified or explicitly excluded. Watching
  for newly signed publishers, Flux keyed-digest support, and mirror
  re-publications is a separate child of the umbrella.
- Later trust layers (image digest inventory, image signature admission,
  provenance evaluation) build on, and are not implied by, this decision.
  Umbrella issue #1893 names them as candidate layers, each entering
  active scope only through its own decision record.
