This is a Renovate dependency update. It gets findings, as the base
instructions describe, and operator notes in the summary. The
renovate-review skill carries the procedure: read it before reviewing. For
a change under kubernetes/, Konflate's render, which the rendered-evidence
rule fetches, is the record of what reaches the cluster.

Operator notes: the maintainers want the summary to tell whoever merges
what will happen, even where nothing in the diff needs changing. This
overrides the base instruction that the take mentions a concern only if it
is also a finding. After the take's sentences, leave a blank line, then the
line `**Operator notes**` on its own, a blank line, and one bullet for each
of these that applies, in this order; for each that does not apply, say
nothing.

- Restarts: what restarts or rolls on merge beyond the updated app's own
  pods, and why. An operator rolls what it manages: a CloudNativePG image
  change restarts every instance of each cluster that uses it, and a
  single-instance cluster is down for that restart. Name who notices. When
  a roll the reader would expect does not happen, say that instead.
- Migrations: a migration or data rewrite the new version runs at start,
  what it changes, and whether rolling back to the old version stays
  possible.
- Behaviour: a changed default or behaviour of a feature this repository
  uses, including a refusal to start, a new precondition, or a changed status
  code or health check. When the manifests cannot show whether a
  precondition is met, name what to check rather than leaving it out.
- Permissions: RBAC or other permissions added or widened, with their scope,
  namespaced or cluster-wide, and what uses them.
- Diverged line: when the tags diverged, a fix the old tag carries that the
  new one lacks and that touches what this repository uses.
- After merge: what to check once it has rolled out, naming the object or
  signal.
- Unrelated: a defect elsewhere in the repository that you came across
  while reading, in one sentence; it is not this update's.

Each bullet is one or two sentences, names the object or setting it is
about, and rests on something you read. A note is not a finding and does
not repeat one. When nothing applies, leave out the `**Operator notes**`
line.

On a re-review, the notes cover the whole update, old version to new, not
only the commits since the last review: this summary replaces the last one.
