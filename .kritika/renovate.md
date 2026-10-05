This is a Renovate dependency update. It gets findings, as the base
instructions describe, and operator notes in the summary.

Read the upstream release notes, changelog and upgrade notes for every
version in the range with gh; the body may be cut. Check each entry against
what this repository sets for the app: its HelmRelease values,
OCIRepository, ExternalSecret, routes, storage and anything else in its
directory. Open the commit range only for an entry that fixes security,
changes authentication or credentials, migrates stored data, changes a
protocol something here speaks, or names a key the manifests set, or when
the notes are missing. For a chart, compare templates/, crds/, values.yaml
and values.schema.json between the two tags rather than trusting the notes.
A digest change under an unchanged tag is a rebuild. For a GitHub Action or
a tool pinned in .mise/, the places to check are the workflows, scripts and
tasks that use it, not an app directory. For a change under kubernetes/,
Konflate's render, which the rendered-evidence rule fetches, is the record
of what reaches the cluster.

Before comparing two tags, check that they are on one line: `gh api
repos/<owner>/<repo>/compare/<old>...<new> --jq '{status, ahead_by,
behind_by}'`. When the status is diverged, the compare starts from the
merge base, not the old tag: a fix the old tag got by backport shows as new
when the new tag has it too, and what the old tag has that the new tag lacks
does not show at all. Read the files at each tag instead.

Findings: report what the update breaks here, a migration or companion
change it makes due, and a pin or workaround in the app's directory it makes
unnecessary, each on the changed version line. A breaking change nothing
here uses is not a finding.

Operator notes: the maintainers want the summary to tell whoever merges
what will happen, even where nothing in the diff needs changing. This
overrides the base instruction that the take mentions a concern only if it
is also a finding. After the take's sentences, leave a blank line, then the
heading `### Operator notes` on its own line, then one bullet for each of
these that applies, in this order; for each that does not apply, say
nothing. That heading is the one exception to the take's "no markdown
headings".

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

Each bullet is one or two sentences, names the object or setting it is
about, and rests on something you read. A note is not a finding and does
not repeat one. When nothing applies, leave out the heading.

On a re-review, the notes cover the whole update, old version to new, not
only the commits since the last review: this summary replaces the last one.
