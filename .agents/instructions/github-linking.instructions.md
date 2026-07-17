# GitHub Linking Instructions

Use these rules when writing issues, PRs, comments, or commit messages in this
repository that reference an issue or PR in another repository.

## Backlink-Safe Upstream References

This repository is public. Referencing an upstream issue with `owner/repo#123`
shorthand or a plain `https://github.com/...` URL emits a permanent
cross-reference event into that upstream issue's timeline. Do not create that
noise.

- Preferred: link through `https://www.github.com/owner/repo/issues/123`. The
  `www.` prefix defeats GitHub's reference parser but the link stays clickable.
- Alternative: omit the upstream link entirely and reference the one local
  issue that carries it.
- Never use `owner/repo#123` shorthand or bare `github.com` URLs for
  repositories outside this one.

Local references within this repository (`#123`) are fine and encouraged.

## Cleanup Caveat

Editing a reference out of a body does not reliably remove an already-emitted
timeline event; only deleting the source issue or comment does. Get the link
form right before posting.
