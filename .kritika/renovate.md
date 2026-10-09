This is a Renovate dependency update. It gets findings, as the base
instructions describe, and operator notes in the summary. The
renovate-review skill carries the procedure, including how to render a
chart update with flate: read it before reviewing.

Operator notes: the maintainers want the summary to tell whoever merges
what will happen, even where nothing in the diff needs changing. This
overrides the base instruction that the take mentions a concern only if it
is also a finding. After the take's sentences, leave a blank line, then the
line `**Operator notes**` on its own, a blank line, and one bullet for each
of these that applies, in this order; for each that does not apply, say
nothing.

- Restarts: what restarts or rolls on merge beyond the updated app's own
  pods, and who notices. An operator rolls what it manages: a CloudNativePG
  image change restarts every instance of each cluster that uses it, and a
  single-instance cluster is down for that restart.
- Migrations: a migration or data rewrite the new version runs at start,
  what it changes, and whether rolling back to the old version stays
  possible.
- Behaviour: a changed default or behaviour of a feature this repository
  uses that needs someone to act or to watch, such as a refusal to start, a
  new precondition, or a changed status code or health check. A fix that
  needs nothing of anyone is not a note.
- Permissions: RBAC or other permissions added or widened, with their scope,
  namespaced or cluster-wide, and what uses them.
- Diverged line: when the tags diverged, a fix the old tag carries that the
  new one lacks and that touches what this repository uses.
- After merge: a check that a note above makes necessary, naming the
  object or signal; not that the new version is running.
- Unrelated: a defect elsewhere in the repository that you came across
  while reading, in one sentence; it is not this update's.

Each bullet is one sentence that names the object or setting and rests on
something you read. It says what happens, never what does not, and does
not explain what the reader already knows. A note is not a finding and
does not repeat one. When nothing applies, leave out the
`**Operator notes**` line.

On a re-review, the notes cover the whole update, old version to new, not
only the commits since the last review: this summary replaces the last one.
