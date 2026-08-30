---
name: github-prose
description: Lifecycle for drafting, reviewing, and posting GitHub prose — issues, pull request bodies, and ADRs — through the owner sign-off flow. Use when writing any of these, from artifact choice to post-merge maintenance.
---

# GitHub Prose

The rules live in `docs/guides/pr-and-issue-writing.md` and `AGENTS.md`;
this skill carries the process and defers to them. Where a line here and
the guide disagree, the guide wins.

## 1. Choose the artifact

Check for an existing tracker before opening anything; extending it beats
duplicating it.

Choose by adoption event, audience, and amendment cost:

- **ADR** (`docs/adr/`) records a standing decision: adopted by merge,
  read later by people who never open issues, amended only by a further
  pull request. Anything with checkboxes, phases, or per-item delivery
  records is not an ADR — that state belongs in an issue that cites it.
- **Issue** is where deciding and tracking happen: adopted by owner
  sign-off, body cheaply editable, closed when its criteria hold.
- **Operations note** (`docs/operations/`) is a living register consulted
  while operating; it is maintained by the pull requests that change what
  it registers.
- Most small issues need no template: a paragraph of prose stating the
  point and its closing condition.

For issue shapes and template selection see
[references/issue-shapes.md](references/issue-shapes.md); for pull
request bodies see [references/pr-shapes.md](references/pr-shapes.md).

## 2. Contract before drafting

- Enumerate the open decisions and put them to the owner before drafting.
  Each decided question deletes more prose than any wording round, and
  hedging in a draft is usually an undecided question wearing a sentence.
- Freeze the template and section structure with the owner. Contract
  silence is a reportable gap, never implicit permission.
- For a set of artifacts that reference each other, state the posting
  order in the draft header. Placeholders resolve by posting order: post
  for a number, substitute it, back-fill the referrer.

## 3. Draft

- One fact per clause, short sentences. Density and accuracy are
  independent axes; a readable rewrite loses no claims.
- Every number is verified by you, this session. Never inherit one.
- State a mechanism's limit, not the universe's: "no X can Y" invites the
  falsification it will get.
- Define coined terms in place; every noun phrase must resolve within the
  document.
- The destination decides wrapping and style — see the guide, including
  its public-safety checklist, before presenting anything.

## 4. Review

Apply [references/review-contract.md](references/review-contract.md).
The owner may skip the review pass explicitly; record the skip rather
than hiding it.

## 5. Sign off and post

- Present the draft in chat; post only after explicit sign-off, and only
  once. Corrections afterwards are edits in place.
- Umbrella children get native sub-issue links at open time, and the
  children table stays the record.
- Append a row to `.private/prose-evidence-log.md` at sign-off, per its
  header rules.
- Rename a generated branch to a descriptive slug before opening the
  pull request.

## 6. Maintain

- The body is the record: tick boxes as work lands, correct wording that
  has become false, fold conclusions in rather than appending them.
- A follow-up that outlives its issue gets its own open issue or umbrella
  row before the parent closes.
- Corrections and retrospective additions read as if they had always been
  there.
