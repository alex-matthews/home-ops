# Editor briefs

Briefs for the editorial gate in [review-contract.md](review-contract.md).
Give the editor the file paths, never the text inline, so the fact sheet
and the draft stay separable. Run the editor on the author's model class
or stronger. A pass on a 200-word body costs about 70,000 tokens and
three minutes.

## Inputs

Files in a scratch directory:

- `rules.md`: `docs/guides/writing-style.md` copied verbatim, plus the
  rules for the destination in `docs/guides/pr-and-issue-writing.md` and
  any template's section order.
- `facts.md`: must-preserve first, then may-cut. Every number, name, and
  decision the body carries is in one list or the other.
- `draft.md`: the title on the first line, then the body as it will be
  posted.
- `artifacts/`: every file the draft adds or changes, copied whole, and a
  diff against the base branch. Without these the adversarial-factual
  lens can only check the body against the fact sheet.

## The single-editor brief

> You are the editorial gate for a public repository. Run three lenses:
> cold reader, technical writing, then adversarial-factual. The cold read
> happens only once, so read `rules.md` first, then `draft.md` cold,
> timing how long you take to answer what changed, why now, and is it
> safe, and noting the sentence that answered each. Only then read
> `artifacts/` and `facts.md`. Apply every rule to every sentence of the
> draft and of any artifact that is prose. Try to falsify each claim
> against the facts and the artifacts. Cut may-cut items that do not
> earn their place. Do not add, drop, soften, or reinterpret a
> must-preserve item. If unsure whether an edit changes meaning, leave it
> and list it. Do not modify files. Reply in full.
>
> Reply with exactly: A. Revised title and body, verbatim, ready to post.
> B. Revised artifact files, verbatim and wrapped at 80 columns, or
> "unchanged". C. Change log, one line per edit with the rule it serves.
> D. Unsure. E. Up to five findings about the rules or the fact sheet
> themselves. F. The three timings and the word count of your revision.

## The second editor

For a body about storage, authentication, or a decision, run a second
editor with the same brief and the adversarial-factual lens first. The
second editor reads `facts.md` before the draft, so it records no
timings. The first editor's timings are the logged measure. Merge the
two revisions by hand. If they disagree, the shorter reading that
preserves every must-preserve item wins.

## After the pass

Merge the revision, resolve the unsure list from facts the editor could
not see, run the shipped-draft reader, and take the rule findings and
the three measures to the evidence log. A finding that a rule produced
worse prose is logged against the rule, not the draft.
