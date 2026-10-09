---
name: renovate-review
description: >-
    Review a Renovate dependency update in this Flux repository: where each
    kind of dependency keeps its upstream history (images, charts and their
    mirrors, GitHub Actions, mise tools), how to compare tags that have
    diverged, what counts as breaking, how deep to go for each update class,
    and what in this repository can depend on the update. Read it for any
    pull request on a renovate/ branch.
---

# Review a Renovate Update

Find what changed upstream between the old and new versions, and whether
anything in this repository depends on it.

## The update

From the title, labels, description and diff, take each package and its
datasource (container image, chart through an OCIRepository, GitHub Action,
mise tool, Grafana dashboard), the old and new version or digest, the
`type/*` label, and the changed files. A group update moves several
packages; each gets the review.

Read the upstream release notes, changelog and upgrade notes for every
version in the range: breaking changes land in the middle of a jump.
Renovate's description carries excerpts in a collapsed Release Notes
section, which is where a long description gets cut: read it whole before
going upstream.

## Finding the upstream

Read upstream on GitHub. A documentation page a note links to is read as
its Markdown source in the repository that holds it: a kritika review
reaches no registry, chart repository or documentation site.

- Renovate's update table links each package's source, on the package name
  or as a separate "source" link, through `redirect.github.com`: read it as
  `github.com`. A registry path names the publisher, not the source: a
  `ghcr.io/home-operations/<app>` image is built in home-operations/containers,
  whose `apps/<app>/docker-bake.hcl` names the upstream as `SOURCE`.
- A chart under `charts-mirror/` republishes another project's chart:
  home-operations/charts-mirror's `apps/<chart>/metadata.yaml` names the
  upstream Helm repository and version, and that project's `Chart.yaml`
  (`sources`, `home`) names its code. Chart and application versions move
  separately: read the chart's notes, and the application's too when
  `appVersion` moved.
- A repository that publishes many charts prefixes its tags with the chart
  name (`<chart>-1.2.3`). When a release is not found, list the releases
  and look for the chart's name.
- A note that says "see #123" is followed to the merged pull request that
  made the change: the issue, and the note itself, often leave its scope
  unclear where the pull request does not.
- Before comparing two tags, check that they are on one line:
  `gh api repos/<owner>/<repo>/compare/<old>...<new> --jq '{status, ahead_by, behind_by}'`.
  When the status is `diverged`, the compare starts from the merge base,
  not the old tag: a fix the old tag got by backport shows as new when the
  new tag has it too, and what the old tag has that the new one lacks does
  not show at all. Read the files at each tag instead, raw with
  `gh api -H "Accept: application/vnd.github.raw+json" "repos/<owner>/<repo>/contents/<path>?ref=<tag>"`.

## Depth

A digest, patch or minor update whose rendered change (or, outside
`kubernetes/`, whose diff) is only version strings and image references,
on any kind of resource, gets the short review, unless its title carries
Renovate's `!` (the preset's mark for a major update, 0.x minors included)
or the render warns about it. Everything else gets the full review. A
warning about a setting that was already there is not this update's, and
an immutable-field warning on a Job is handled when its template carries
Helm hook annotations with a delete policy.

The short review:

- Check each release-note entry against what this repository sets for the
  app: its HelmRelease values, OCIRepository, ExternalSecret, routes and
  storage.
- Open the commit range only for an entry that fixes security; changes
  authentication, credentials or sessions; migrates stored data; changes a
  protocol or API something here speaks; or names a key the manifests set.
  Open it too when the notes are missing.
- Leave the image's build, base layers and bundled libraries alone.
- A digest change under an unchanged tag is a rebuild: say so, and do not
  attribute it to a commit without build metadata.

The full review adds:

- Both the wrapper and what it wraps: chart and application, image and
  software, Action and the tool it runs. Where the notes are thin, read the
  commits between the tags.
- For a chart, a comparison of `templates/`, `crds/`, `values.yaml`,
  `values.schema.json` and subcharts between the two tags rather than
  trust in the notes; README, tests and CI can be skipped.
- Each upstream change traced through the app's OCIRepository and
  HelmRelease, the Kustomization's patches and components, ConfigMaps,
  routes, storage, RBAC and consumers, including proxies and clients that
  speak its protocol.
- For an operator, the workloads it creates, for runtime changes the render
  does not show.
- Every risk surface below that the update touches.

## Rendering a chart update

For a chart bump, render the HelmRelease with the new chart and this
repository's values, from the repository root, with the namespace's
directory as the path:

```
flate build hr <name> --path kubernetes/apps/<namespace> --no-progress
```

A HelmRelease whose Kustomization depends on one in another namespace is
reported as blocked there; render it from the whole tree instead, which
takes several times the memory:

```
flate build hr <name> -n <namespace> --path kubernetes/flux/cluster --no-progress
```

flate reports every failure in the namespace, not only the requested
HelmRelease's, and exits nonzero for any of them. A failure is a finding
on the bumped line only when it belongs to the HelmRelease under review
and the update caused it: a value the new chart's schema rejects, a
template that errors on this repository's values. A failure of another
HelmRelease, or a source that could not be fetched, says nothing about the
update.

A render that succeeds is an offline approximation of what the cluster
applies: CRDs and Secrets are left out, `${SECRET_DOMAIN}` and other
substitutions stay unresolved, and templates that branch on Kubernetes
capabilities see flate's bundled version, not the cluster's. Take label
values, resource names and ports from the render rather than from a
reading of the template, and narrow it with `--show-only <template path>`
when the whole output is too long. Only the head is checked out, so the
old chart does not render here: read what it produced upstream at the old
tag.

## What breaks

Look in each release for breaking-change markers; removed or renamed
values, CRD fields, environment variables and flags; a new minimum
Kubernetes, Flux or Talos version; one-way schema or data migrations;
changed defaults (authentication, storage class, ports, probes);
deprecations that became errors; new required keys with no default; and a
label value or resource name that changed while its key stayed, which
breaks whatever selects on the old value while a search for the key still
matches. Minor and patch releases carry these too. When a note such as
"prefix removed" leaves its scope unclear, settle it from the upstream pull
request or the template, not the sentence.

A finding is what the update breaks here, a migration or companion change
it makes due, or a pin, override or workaround in the app's directory it
makes unnecessary; a comment citing an upstream issue or version often
marks the last kind. Each sits on the version line the update moved, and
its explanation names the file and line here that depend on the change. A
breaking change nothing here uses is not a finding.

## What depends on it

The question is not whether this repository sets the old thing but whether
anything here depends on it. Search `kubernetes/` for:

- a label key or value: whatever selects on it, such as monitors, network
  policies, disruption budgets, and label matchers in alert rules and
  dashboards;
- a resource name: whatever refers to it, such as route backends, cluster
  DNS names (`<name>.<namespace>.svc`), and Flux `dependsOn` and
  `healthChecks`;
- a value, flag or CRD field: HelmRelease `values`, `valuesFrom` and
  `postRenderers`, Kustomize patches, and the custom resources other apps
  create from the dependency's CRDs.

For a GitHub Action or a mise tool, search instead the workflows, scripts
and tasks that use it. Before writing that nothing here sets a key, search
the app's whole directory, its ExternalSecret included. Once each search
has come back empty or with a short list, stop: rephrasing it adds nothing.

These risk surfaces need evidence whatever the update class; "patch
release" is not evidence:

- CRD schema, versions or conversion webhooks. Name tightened validations,
  removed fields or enum values, and version or conversion changes. A
  conversion webhook needs its Service and Deployment to render or to
  exist already. How CRDs reach the cluster, including the ones
  `bootstrap/helmfile/` applies, is in
  [docs/policy/decisions.md#crd-upgrades](../../../docs/policy/decisions.md#crd-upgrades).
- A webhook's Service, Deployment or certificates.
- RBAC or a ServiceAccount.
- PVCs, storage, backups or Kopiur objects; protected claims come from
  [kubernetes/components/kopiur](../../../kubernetes/components/kopiur/kustomization.yaml).
- `runAsUser`, `runAsGroup`, `fsGroup` or `fsGroupChangePolicy` on a
  workload with persistence: name the claim, the mount path and the policy.
- Routes, gateways or public hostnames:
  [docs/policy/public-surfaces.md](../../../docs/policy/public-surfaces.md).
- Authentication.
- An image that moves registry or repository.

Before prescribing a rename or a new value, confirm it from the upstream
pull request's diff or the template at the new tag. Without that, name it
as a check after merge rather than an edit: a wrong edit that gets applied
is worse than none.

## Before writing

- When [.renovaterc.json5](../../../.renovaterc.json5) automerges this
  update, it can merge before this review lands
  ([ARCHITECTURE.md#what-ci-proves](../../../ARCHITECTURE.md#what-ci-proves)):
  write for someone reading after the merge.
- Never name a secret key.
