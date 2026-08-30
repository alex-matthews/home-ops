# Issue shapes

Maps recurring issue shapes to their template in `.github/ISSUE_TEMPLATE/`
and a merged exemplar. Templates are starting shapes: delete sections that
do not apply, rename a heading when that makes its contents more accurate.
Every exemplar below is local; read it before drafting the same shape.

| Shape                      | Template                  | Exemplar    | Notes                                                                                 |
| -------------------------- | ------------------------- | ----------- | ------------------------------------------------------------------------------------- |
| Design proposal            | design-proposal           | #1912       | Decide among alternatives; body records the agreed design.                            |
| Operational investigation  | operational-investigation | —           | Observation → diagnosis → correction, evidence-led.                                   |
| Umbrella                   | umbrella                  | #1768       | Coordinates children; never implements. Sub-issue links at open time.                 |
| Programme tracking         | tracking                  | #1872       | Doctrine and state for multi-PR work; principles as summary + pointer.                |
| Decision-tracking stub     | tracking                  | #1233       | Principles and current-state sections deleted; adoption boxes tied to merges.         |
| Audit findings             | audit-findings            | #1906       | Categories public, identities in `.private/`; findings feed named successors.         |
| Small capture or follow-up | none                      | #1899–#1902 | One paragraph of prose with a closing condition; check for an existing tracker first. |
| Decision checkpoint        | none                      | #1899       | Verdict-first, per-trigger bullets, dated next checkpoint carried in the title.       |

Shape selection failures worth knowing: the #1233 body took four shape
pivots because the artifact class was chosen after drafting instead of
before — run the skill's step 1 first; and a one-round convergence can
still ship a framing defect when the lead borrows another artifact's
classification language, so restate the rule in this issue's own terms.
