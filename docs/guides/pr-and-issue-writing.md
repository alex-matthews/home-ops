# Issue and PR Writing

**When to use:** Writing or editing an issue body, pull request description, or comment; public prose; linking to another repository; sanitising something already published.

Issues and pull requests are the durable public record of why this repository
changed. Write them for someone reading in six months, not for the moment of
writing.

The test for any sentence: would it exist if the work had been done right the
first time, and does it help a later reader? If neither, cut it.

## Issues

The body is the record. Keep it true as work lands — tick checkboxes, correct
wording that has become false, and fold conclusions into the body rather than
appending them.

Reserve comments for substantive evidence, at most one per milestone. A comment
per phase of work is noise; a reader wants one accurate summary, not a
transcript of how it was reached.

When something already published turns out wrong, edit it in place
(`gh api -X PATCH /repos/{owner}/{repo}/issues/comments/{id}`) and delete the
follow-up. Never stack a "correcting my earlier comment" reply. When correcting
a body, rewrite it to length rather than bolting the correction onto the old
structure — a section narrating a wrong call is itself the problem.

Keep operational lessons; drop the chronology. "What we learned that changes
future behaviour" survives. "Step 4 completed successfully" does not.

## Pull requests

Open with the substance in a sentence or two. No summary preamble, no restating
the request.

Lead with evidence. Concrete numbers carry an argument better than adjectives:
"18 chart fetches failed, 4 on a re-run of the identical tree, 0 after this
change" _is_ the argument.

Headings are earned, not defaulted. A small change needs none — two or three
sentences of prose is the whole body. When a body does have separable parts,
prefer a heading that carries the argument (`### Why a DaemonSet and not a
volume on the runner pod`) over a category label (`## Changes`).

Length should track the change, not the effort spent on it. A long body is
right when the reasoning is long; a one-line diff with a validation matrix is
not.

### Keeping the body current

The body is the durable record, and it is the only one. The squash commit takes
the pull request title and carries no body, so `git log` and `git blame` give a
reader the subject and the `(#123)` pointer and nothing else. Everything that
explains a change lives here.

Commit messages serve review only. A squash merge discards them — the branch
commits never reach `main` — so reasoning written into them is gone at merge.
Keep subjects informative enough to follow a branch while it is open and leave
the argument to the body.

The body being the only copy is deliberate. A copy frozen into a commit could
not be corrected afterwards, so a body that turned out wrong would disagree
with the commit permanently. One editable record means a correction is the
record.

Most pull requests here open and merge within the hour and need no refresh.
Update the body when one outlives a single sitting: when scope changes, when
review turns up something it now contradicts, or before asking for a merge on a
branch that has moved since it was opened.

### Validation

State what was checked and what it showed. Command invocations with their
flags, cache directories and skip tallies belong in CI logs, not in prose:

> Rendered the chart with these values and ran the resulting Corefile against
> `coredns:1.14.6`: config parses and starts clean, `AAAA cloudflare.com`
> returns NODATA with SOA in authority, `A github.com` resolves normally.

Not a list of every command with its `--cache-dir`, followed by
`4 resources found: 1 valid, 0 invalid, 3 skipped`.

### Post-merge instructions

Include a rollout runbook only when the change does not take effect on its own
— a Talos schematic change needing a node-by-node upgrade, for example. The
runbook is then the substance of the pull request and stays useful later.

Omit it when Flux applies the change automatically. "After merging, start a new
session and confirm the tools appear" is a note to yourself during review, and
goes stale the moment it merges.

## Both

No ceremony headers, no emoji, no AI attribution, no celebratory closing.

Do not hard-wrap. Repository files and commit messages wrap at 80 columns;
issue and pull request bodies, review comments, and release notes take one line
per paragraph and let the browser wrap them. The destination decides, not the
file the text was drafted in — GitHub prose drafted in a scratch markdown file
beside 80-column repository files is exactly where this goes wrong.

Nothing that only makes sense while the work is open: instructions to
collaborators, merge ordering, rebase recipes, in-flight status, or
restatements of the rules in `AGENTS.md`.

Review a version bump on that bump's own pull request rather than bundling it
into a later one — someone asking why a version landed looks at that version's
pull request. A retrospective comment on a merged pull request is acceptable
and better than the alternative; write it as if it had always been there, with
no trace of the recovery.

## Public safety

This repository is public. `AGENTS.md` lists what must never appear in public
prose; check a draft against it before posting.

The practical move is to keep exact values in terminal output or local notes
and name the category instead — "a zone-scoped DNS token" rather than the item
that holds it, "the NAS export" rather than its hostname and path. If naming
the thing adds nothing to the argument, it is noise as well as exposure.

To sanitise something already published, delete and repost. Edit history stays
publicly visible after an edit.

## Linking to other repositories

Referencing an upstream issue with `owner/repo#123` shorthand or a plain
`https://github.com/...` URL emits a permanent cross-reference event into that
upstream issue's timeline. Do not create that noise.

- Preferred: link through `https://www.github.com/owner/repo/issues/123`. The
  `www.` prefix defeats GitHub's reference parser but the link stays clickable.
- Alternative: omit the upstream link entirely and reference the one local
  issue that carries it.
- Never use `owner/repo#123` shorthand or bare `github.com` URLs for
  repositories outside this one.

Local references within this repository (`#123`) are fine and encouraged.

Editing a reference out of a body does not reliably remove an already-emitted
timeline event; only deleting the source issue or comment does. Get the link
form right before posting.
