# Documentation

Durable project documentation for the home-ops repository. Keep scratch
notes, raw agent transcripts, and one-off prompt experiments out of this tree.

Routing lives in [`AGENTS.md`](../AGENTS.md): its task table names the
document to read for each kind of work. This page describes the directories
and records what was retired.

## Directories

- `adr/`: why the repository, cluster, or operating model is shaped a certain
  way. A decision record holds the decision and its consequences only.
- `guides/`: how to work in this repository or use its tooling.
- `operations/`: how the live cluster is operated, restored, migrated, or
  understood. Architecture reference and current-state inventories belong
  here, where they can be corrected without rewriting a decision.

The root `README.md` is the repository's front page, curated for a visitor,
not an index of operational documents.

## Retired Documents

Each row names the last commit that contained the document, so it can be
read offline from a clone containing that commit: search with
`git grep -n -e '<phrase>' <sha> -- docs .agents/skills` and read with
`git show <sha>:<path>`.

| Path                                                        | Last commit containing it | Replaced by                      |
| ----------------------------------------------------------- | ------------------------- | -------------------------------- |
| `docs/guides/pr-and-issue-writing.md`                       | `0becf529`                | `docs/guides/writing.md`         |
| `docs/guides/writing-style.md`                              | `0becf529`                | `docs/guides/writing.md`         |
| `.agents/skills/github-prose/SKILL.md`                      | `0becf529`                | `docs/guides/writing.md`         |
| `.agents/skills/github-prose/references/issue-shapes.md`    | `0becf529`                | `docs/guides/writing-shapes.md`  |
| `.agents/skills/github-prose/references/pr-shapes.md`       | `0becf529`                | `docs/guides/writing-shapes.md`  |
| `.agents/skills/github-prose/references/review-contract.md` | `0becf529`                | `docs/guides/writing.md`, Verify |
| `.agents/skills/github-prose/references/editor-briefs.md`   | `0becf529`                | retired without replacement      |
