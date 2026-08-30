# Pull request body shapes

There is no `.github/` template for pull requests by design: agents pass
the body explicitly, and GitHub offers no chooser for multiple pull
request templates. The shape lives here instead. Every exemplar is a
merged local pull request; read it before drafting the same shape.

## The spine, common to all shapes

1. Substance lead: what changed and why, in one or two sentences. No
   preamble, no restating the request.
2. Per-motion bullets when the change has more than two separable
   motions, kept parallel in form.
3. Validation: what was checked, what it showed, and what it cannot show.
   Evidence-time detail, not command dumps.
4. Live-effect or follow-up closer, only when the change has one.

Properties and invariants live in one durable document or nowhere; the
body states what changed and what was checked. When review falsifies a
claim, fix it by removing or shortening it, never by fencing it.

## Shapes

| Shape                                   | Exemplar     | What distinguishes it                                                                                                                 |
| --------------------------------------- | ------------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| Mechanical batch change                 | #1877, #1884 | Lead names the batch and its rule; per-class bullets; a retained/held statement for what deliberately did not change.                 |
| Gap-closing addition                    | #1878        | Gap stated first; per-item gap → fix → verification bullets; a scope-boundary section for what this does not change.                  |
| Doctrine change                         | #1885        | Doctrine lead; per-motion bullets (reinstates, removes, stays, exception); final-state line.                                          |
| Record correction                       | #1887, #1892 | Completion lead; evidence compressed to bullet leads; correct-in-place applies to misleading-but-not-false claims too.                |
| ADR-adopting docs                       | #1895, #1896 | Why-now plus pointer; the merge is the decision; the body never re-argues the ADR's content.                                          |
| Implementation with verification limits | #1904        | Phase-and-authority lead; per-source bullets; validation paragraph separating what pre-merge checks prove from what stays post-merge. |

A version bump is reviewed on its own pull request; Renovate writes those
bodies. For everything else, if no shape fits, use the spine alone —
naming a new shape is worth a prose-log note.
