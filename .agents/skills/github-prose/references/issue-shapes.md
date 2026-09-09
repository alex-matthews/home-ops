# Issue shapes

This file maps recurring issue shapes to their template in
`.github/ISSUE_TEMPLATE/` and to one local exemplar issue. The guide's
Choosing a shape section owns the template descriptions. Read the
exemplar before drafting the same shape.

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

An exemplar illustrates its shape and never decides a verdict. Each one
carries the date its body was posted or last rewritten and its one known
flaw against `docs/guides/writing-style.md`, so nobody copies the flaw. A
better body replaces an exemplar in a distillation session (#2047). Only
#2047 and later were drafted under that guide.

Shape selection failures worth knowing: the #1233 body took four shape
pivots because the artifact class was chosen after drafting instead of
before. Run the skill's step 1 first. A one-round convergence can still
ship a framing defect if the lead borrows another artifact's
classification language, so restate the rule in this issue's own terms.
