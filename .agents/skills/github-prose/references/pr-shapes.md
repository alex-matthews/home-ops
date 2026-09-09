# Pull request body shapes

There is no `.github/` template for pull requests by design. Agents pass
the body explicitly, and GitHub offers no chooser for multiple pull
request templates. The shape lives here instead. Every exemplar is a
merged local pull request. Read it before drafting the same shape.

## The spine, common to all shapes

1. Substance lead: what changed and why, in one or two sentences. No
   preamble, no restating the request.
2. Per-motion bullets only if the change has more than two separable
   motions, kept parallel in form.
3. Validation: what was checked, what it showed, and what it cannot show.
   Evidence-time detail, not command dumps.
4. Live-effect or follow-up closer, only if the change has one.

Properties and invariants live in one durable document or nowhere. The
body states what changed and what was checked.

## Shapes

| Shape                                   | Exemplar (date)    | What distinguishes it                                                                                                                       | Known flaw                                                                                                    |
| --------------------------------------- | ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| Mechanical batch change                 | #1884 (2026-08-29) | Lead names the batch and its rule; per-class bullets; a retained/held statement for what deliberately did not change.                       | The lead's second sentence chains four causal links.                                                          |
| Gap-closing addition                    | #1878 (2026-08-28) | Gap stated first; per-item gap → fix → verification bullets; a scope-boundary section for what this does not change.                        | Each remediation bullet packs three causal links into one sentence.                                           |
| Doctrine change                         | #1885 (2026-08-29) | Doctrine lead; per-motion bullets (reinstates, removes, stays, exception); final-state line.                                                | The doctrine arrives as one 55-word lead sentence joined by a colon and two semicolons.                       |
| Record correction                       | #1892 (2026-08-30) | Completion lead; evidence compressed to bullet leads; correct-in-place applies to misleading-but-not-false claims too.                      | The body never says the change is documentation only, so "is it safe" is answerable only from the diff.       |
| ADR-adopting docs                       | #1896 (2026-08-30) | Why-now plus pointer; the merge is the decision; the body never re-argues the ADR's content.                                                | The lead uses "today", a clock word outside a Current state section.                                          |
| Implementation with verification limits | #1904 (2026-08-30) | Phase-and-authority lead; per-source bullets; validation paragraph separating what pre-merge checks prove from what stays post-merge.       | "re-validated today" in a body whose point is a dated baseline.                                               |
| Mirror pull request                     | #2046 (2026-09-09) | Trigger-first lead; verdict before proof, scoped; validation split into verified and expected; trailing adapted-from link with differences. | The lead ends on a forecast about other repositories ("ahead of radarr and prowlarr porting the same check"). |
| Urgent fix                              | #2008 (2026-09-04) | Incident lead with the measured symptom; the one change and its number; what proves it, named as pending.                                   | The validation is an unlabelled fragment where the spine asks for a labelled section.                         |
| Docs-only                               | #2004 (2026-09-04) | Observation lead; the negative path recorded as evidence; "docs only" as the safety line.                                                   | The evidence paragraph is one 60-word sentence spliced by two semicolons.                                     |

A version bump is reviewed on its own pull request, and Renovate writes
those bodies. For everything else, use the spine alone if no shape fits.
Naming a new shape is worth a prose-log note.

An exemplar illustrates its shape and never decides a verdict. Each row
carries the date the body was merged and its one known flaw against
`docs/guides/writing-style.md`, so nobody copies the flaw. Only bodies
from 2026-09-09 onward were drafted under that guide. Earlier exemplars
break rules that did not exist when they were written. A better body
replaces an exemplar in a distillation session (#2047).
