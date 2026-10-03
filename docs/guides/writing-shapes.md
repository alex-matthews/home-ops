# Writing shapes

**When to use:** Choosing the shape of an issue body or pull request body
in step 1 or 3 of [`writing.md`](writing.md). Each row names one merged or
posted local example; read it before drafting the same shape. An exemplar
illustrates its shape and never decides a verdict, and each carries its one
known flaw so nobody copies it. A better body replaces an exemplar in a pull
request that says why.

## Issue shapes

Templates live in `.github/ISSUE_TEMPLATE/`.

| Shape                      | Template                  | Exemplar (date)    | Notes                                                                                 | Known flaw                                                                                 |
| -------------------------- | ------------------------- | ------------------ | ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| Design proposal            | design-proposal           | #1912 (2026-08-30) | Decide among alternatives; body records the agreed design.                            | The body says "Decided at review" four times and never names or dates the review.          |
| Operational investigation  | operational-investigation | #1298 (2026-07-29) | Observation → cause → recovery → residual notes, evidence-led.                        | The verdict ("session timing needs no change") is withheld to the last section.            |
| Umbrella                   | umbrella                  | #1768 (2026-08-12) | Coordinates children; never implements. Sub-issue links at open time.                 | Rows 5 and 6 of the children table name the same issue without saying they merged.         |
| Programme tracking         | tracking                  | #1872 (2026-09-04) | Doctrine and state for multi-PR work; principles as summary + pointer.                | Current state is one 380-word paragraph running six PR narratives together.                |
| Decision-tracking stub     | tracking                  | #1233 (2026-08-30) | Principles and current-state sections deleted; adoption boxes tied to merges.         | The only open box sits last, under three ticked ones.                                      |
| Audit findings             | audit-findings            | #1906 (2026-09-04) | Categories public, identities in `.private/`; findings feed named successors.         | The status "Resolved pending verification" calls one finding both resolved and unverified. |
| Small capture or follow-up | none                      | #1901 (2026-08-30) | One paragraph of prose with a closing condition; check for an existing tracker first. | The first box bundles three independent observations into one tick.                        |
| Decision checkpoint        | none                      | #1899 (2026-08-30) | Verdict-first, per-trigger bullets, dated next checkpoint carried in the title.       | A trigger bullet states its condition with "when" ("or when a 1.0 ... lands").             |

The #1233 body took four shape pivots because the artifact class was chosen
after drafting instead of before; choose it first.

## Pull request shapes

There is no `.github/` template for pull requests by design: agents pass the
body explicitly, and GitHub offers no chooser for multiple templates. A
version bump is reviewed on its own pull request, and Renovate writes those
bodies. For everything else, use the spine in `writing.md` alone if no shape
fits.

| Shape                                   | Exemplar (date)    | What distinguishes it                                                                                                                       | Known flaw                                                                                                    |
| --------------------------------------- | ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| Mechanical batch change                 | #1884 (2026-08-29) | Lead names the batch and its rule; per-class bullets; a retained/held statement for what deliberately did not change.                       | The lead's second sentence chains four causal links.                                                          |
| Gap-closing addition                    | #1878 (2026-08-28) | Gap stated first; per-item gap → fix → verification bullets; a scope-boundary section for what this does not change.                        | Each remediation bullet packs three causal links into one sentence.                                           |
| Doctrine change                         | #1885 (2026-08-29) | Doctrine lead; per-motion bullets (reinstates, removes, stays, exception); final-state line.                                                | The doctrine arrives as one 55-word lead sentence joined by a colon and two semicolons.                       |
| Record correction                       | #1892 (2026-08-30) | Completion lead; evidence compressed to bullet leads; correct-in-place applies to misleading-but-not-false claims too.                      | The body never says the change is documentation only, so "is it safe" is answerable only from the diff.       |
| ADR-adopting docs                       | #1896 (2026-08-30) | Why-now plus pointer; the merge is the decision; the body never re-argues the ADR's content.                                                | The lead uses "today", a clock word.                                                                          |
| Implementation with verification limits | #1904 (2026-08-30) | Phase-and-authority lead; per-source bullets; validation paragraph separating what pre-merge checks prove from what stays post-merge.       | "re-validated today" in a body whose point is a dated baseline.                                               |
| Mirror pull request                     | #2046 (2026-09-09) | Trigger-first lead; verdict before proof, scoped; validation split into verified and expected; trailing adapted-from link with differences. | The lead ends on a forecast about other repositories ("ahead of radarr and prowlarr porting the same check"). |
| Urgent fix                              | #2008 (2026-09-04) | Incident lead with the measured symptom; the one change and its number; what proves it, named as pending.                                   | The validation is an unlabelled fragment where the spine asks for a labelled section.                         |
| Docs-only                               | #2004 (2026-09-04) | Observation lead; the negative path recorded as evidence; "docs only" as the safety line.                                                   | The evidence paragraph is one 60-word sentence spliced by two semicolons.                                     |
