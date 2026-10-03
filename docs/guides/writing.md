# Writing

**When to use:** Drafting, reviewing, or editing an issue body, pull request
description, comment, or ADR; sanitising something already published; linking
to another repository.

Issues and pull requests are the durable public record of why this repository
changed. Write for someone reading in six months, not for the moment of
writing. The reader is a human operator who knows Kubernetes and Flux and has
never seen this repository. A body that describes a change succeeds if that
reader can answer three questions in one pass: what changed, why now, and is
it safe.

## 1. Choose the artifact

Check for an existing tracker before opening anything; extending it beats
duplicating it. Choose by adoption event, audience, and amendment cost:

- **ADR** (`docs/adr/`) records a standing decision: adopted by merge, read
  later by people who never open issues, amended only by a further pull
  request. Anything with checkboxes, phases, or per-item delivery records is
  not an ADR.
- **Issue** is where deciding and tracking happen: adopted by owner sign-off,
  body cheaply editable, closed when its criteria hold. Most small issues need
  no template: a paragraph stating the point and its closing condition. Larger
  work starts from a template in `.github/ISSUE_TEMPLATE/` (operational
  investigation, design proposal, umbrella, tracking, audit findings); delete
  sections that do not apply.
- **Operations note** (`docs/operations/`) is a living register consulted
  while operating, maintained by the pull requests that change what it
  registers.

Shapes and one worked example per shape are in
[`writing-shapes.md`](writing-shapes.md).

## 2. Settle open decisions

If the draft depends on a decision only the owner can make, put that question
first and draft after the answer. Hedging in a draft is usually an undecided
question wearing a sentence. For a set of artifacts that reference each other,
state the posting order; placeholders resolve by posting order.

## 3. Draft

A pull request body has a spine: the substance in one or two sentences, what
changed and why; per-motion bullets only if there are more than two separable
motions; what was checked, what it showed, and what it cannot show; a
live-effect or follow-up closer only if there is one. Headings are earned, not
defaulted, and length tracks the change, not the effort spent on it.

- Lead with the trigger and the change together, never with the diff. State
  the verdict before its proof and let it name what it covers.
- One causal link per sentence. Name the actor. Define a term in the sentence
  that first depends on it, and use one name per thing.
- Print a configuration name or value in code font and gloss it in the
  direction the name reads.
- Cut history the reader never acts on, and the clock: no "today", no
  "recently", no forecasts about other repositories.
- Mark every unobserved outcome once, up front: "Expected after reconcile, not
  yet observed:".
- A body mirroring a peer's change restates the peer's reasoning in local
  terms and stands if the peer's body vanished.
- Every number is verified by you, this session, and every source you cite is
  one you read. A claim you have not checked says "not checked".

## 4. Verify

Try to falsify your own claims, weakest first, against the manifests, the
diff, and the sources. Fix a wrong claim by removing or shortening it, never
by fencing it with qualifiers.

A separate reviewer reads the draft only when a wrong claim would be costly:
the change is irreversible, touches credentials, auth, or storage, or cannot be
verified before merge. Give the reviewer the draft together with the files it
adds or changes and the diff against the base branch, so it can falsify claims
against the artifacts rather than the prose. Substantive findings are the
output; a preference is labelled as one. Record the review's tokens and time
with its findings. A change that cannot be verified after merge either is a
separate gap: say so in the validation plan. A Renovate bump gets nothing
beyond the bot's review.

## 5. Sign off and post

Post when requested and authorised; otherwise present the draft for
approval. Reuse existing authorisation. Post once and edit corrections in
place. Rename a generated branch to a
short descriptive slug before opening the pull request; a head branch cannot
be renamed afterwards. Link umbrella children as native sub-issues when they
open; the children table stays the record of status.

## 6. Keep the body current

The body is the durable record, and it is the only one: the squash commit
carries the title and nothing else, so everything that explains a change lives
here. Tick checkboxes as work lands, correct wording that has become false, and
fold conclusions into the body rather than appending them. Update a pull
request body when scope changes, when review contradicts it, or before asking
for a merge on a branch that has moved.

Reserve comments for substantive evidence, at most one per milestone. Correct
a published mistake in place and delete the follow-up; never stack a
"correcting my earlier comment" reply. A retrospective comment on a merged
pull request is written as if it had always been there.

A follow-up that should outlive its issue exists as its own open issue, or a
row in an open umbrella, before the issue that spawned it closes.

## Reference

**Both issues and pull requests.** No ceremony headers, no emoji, no AI
attribution, no celebratory closing. Do not hard-wrap: repository files wrap
at 80 columns, but issue and pull request bodies, comments, and release notes
take one line per paragraph and let the browser wrap. Nothing that only makes
sense while the work is open: merge ordering, rebase recipes, in-flight
status, restatements of `AGENTS.md`. Review a version bump on that bump's own
pull request. Include a rollout runbook only when the change does not take
effect on its own.

**Public safety.** `AGENTS.md` lists what must never appear in public prose;
check a draft against it before posting. Keep exact values in terminal output
or local notes and name the category instead: "a zone-scoped DNS token", "the
NAS export". To sanitise something already published, delete and repost; edit
history stays visible.

**Linking to other repositories.** `owner/repo#123` shorthand or a plain
`https://github.com/...` URL emits a permanent cross-reference into the
upstream issue's timeline. Link through `https://www.github.com/owner/repo/...`
instead, or omit the upstream link and cite the local issue that carries it.
Local `#123` references are fine. Editing a reference out afterwards does not
remove the event; get the form right before posting.

**Audit-shaped findings** go where the driving issue directs, with an
at-a-glance table once there are more than a few, and with topology,
addresses, and identifiers kept to private notes.
