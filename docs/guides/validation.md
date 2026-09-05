# Validation and Tooling

**When to use:** What to run before merging, render, flate, Konflate, kubeconform, image diff, bypass merge, CI boundaries, `just` versus `mise`, release notes, Renovate PR Review bot, firing alerts, Alertmanager, silences.

Use the smallest validation set that matches the change. What to run, what each
check actually proves, and where the tooling boundaries sit. For querying
logs, metrics, and dashboards while investigating live behaviour, see
[`../operations/observability.md`](../operations/observability.md).

## Commands

Formatting and workflow checks:

```sh
mise exec --no-deps -- actionlint
mise exec --no-deps -- zizmor --offline .github/workflows
mise exec --no-deps -- oxfmt --check . '!**/*.sops.yaml' '!**/*.sops.yml'
```

Flux and Kubernetes rendering:

```sh
mise exec -- flate test all -p ./kubernetes/flux/cluster --allow-missing-secrets
```

Image diff for Kubernetes app changes:

```sh
mise exec -- flate diff images -p ./kubernetes/flux/cluster -o json
```

For a quick Kustomize-only smoke test, render the touched namespace or app
directory when possible:

```sh
mise exec -- kubectl kustomize kubernetes/apps/<namespace>/<app>/app
```

`kubectl apply --dry-run=server` needs the same RBAC verbs as a real apply
even though nothing is persisted, and the ambient kubeconfig is read-only, so
a server dry-run needs the administrative identity named explicitly:
`mise exec -- kubectl --kubeconfig ./kubeconfig apply --dry-run=server ...`
(the flag, not the environment — mise overrides an exported `KUBECONFIG`).
The same applies to port-forward and exec, which are subresource creates the
read-only identity cannot make; a Prometheus or Alertmanager query through a
denied port-forward reads as empty, not as an error, so confirm the tunnel
before trusting a zero. Details in
[`../operations/talos-access-and-break-glass.md`](../operations/talos-access-and-break-glass.md).

## What a local render does not prove

The rendered `FluxInstance` pins its sync source to the remote `main` branch.
Flate follows that source when resolving child Kustomization content, so a
successful local run proves the baseline on the remote `main` branch is
renderable — not your branch's commits — and can miss branch-only changes
beneath those child paths. Do not cite it as branch-diff
evidence without first proving the changed objects appear in its output. Use
the Konflate pull-request render, or an explicitly branch-aware disposable
render, as the authority for those changes.

## What release notes do not prove

Release notes describe the code. They do not describe what a chart's templates
ship, and chart-shipped resources are where the deployed surface actually
changes. Reviewing an upgrade from release notes alone will miss those.

The Renovate PR Review bot reads the chart templates, so read its comment
before merging a Renovate PR. On kopiur 0.9.1 it caught a new default-on
cluster-scoped `FlowSchema` that a release-notes-only review missed entirely —
see [`../operations/storage-and-backups.md`](../operations/storage-and-backups.md).

Treat its blocker-level findings as high-priority signals rather than
advisory. If it flags something this repo documents as intentional, fix the
reviewer's prompt — it is inline in `.github/workflows/renovate-review.yaml` —
rather than learning to skip the comment.

## CRD lifecycle in this cluster

The `cluster-apps` Kustomization patches every child Kustomization so its
HelmReleases receive `install.crds: CreateReplace` and
`upgrade.crds: CreateReplace`; leaf HelmRelease files therefore omit those
fields without inheriting Helm's skip-on-upgrade behavior. Chart CRDs in the
special `crds/` directory are installed and replaced during reconciliation.

When reviewing a chart upgrade, treat shipped CRD schema changes and new CRDs
as changes that will reach the cluster. Verify the repo-wide patch in
`kubernetes/flux/cluster/ks.yaml`; do not infer the effective policy from the
leaf HelmRelease alone or from Helm's default CRD behavior.

A Renovate bump of a chart that ships CRDs is free evidence for both halves
of that claim. Diff `helm show crds` between the pinned and proposed versions
to see what schema will change, and after the merge check that the live CRD's
generation moved under helm-controller's field manager. The kopiur 0.10.7 bump
on 2026-09-05 proved the replace path this way (#1872).

## What a chart verification failure does

Every eligible `OCIRepository` carries a `verify` block (ADR-0003). When
source-controller cannot match the artifact's signature to the pinned
identity, the source reports `SourceVerified=False` with the cosign error
in its message and `Ready=False`, and nothing else moves: the previously
stored artifact stays in storage, the HelmRelease that consumes it keeps
running its current revision, and every other source and release
reconciles as before. The failure freezes that one chart at its last
verified revision; it never uninstalls or degrades anything. Verification
runs only when the fetched digest or the source spec changes, so a source
that verified once is not re-verified on its interval.

Two things produce the state, and each has one fix:

- A tag bump that Renovate merged is signed by an identity the manifest's
  regex no longer matches (signer drift). Re-observe the certificate on
  the new artifact with `cosign verify` and update the regex in a pull
  request that cites it, or revert the bump. Do not loosen the regex to
  make the error go away.
- An edit to the `verify` block itself is wrong. Correct it; the next
  reconcile re-verifies and stores the artifact.

A source with `SourceVerified=False` and no `status.artifact` has never
verified since it was created; a source with both has a stored artifact
from before the failure, and `ArtifactInStorage` stays `True`. Read both
before deciding whether anything is at risk. Observed live on
source-controller v1.9.5 on 2026-09-05 with a scratch source: a wrong
identity on a fresh source stored nothing; the corrected identity verified
and stored the artifact; the wrong identity applied again left that
artifact in place and flipped only the verification and readiness
conditions. The record is in #1894.

## What a firing alert does not prove

Prometheus reports an alert as firing whether or not it is silenced — silencing
is an Alertmanager concept. Querying Prometheus `/api/v1/alerts` tells you what
is evaluating true, not what needs attention.

Ask Alertmanager instead. `/api/v2/alerts` marks each alert `active` or
`suppressed` and carries `silencedBy` and `inhibitedBy`, so the actionable set
is whatever is active and not suppressed. Long-standing benign warnings are silenced
deliberately and declaratively — the CRs live in
`kubernetes/apps/observability/silence-operator/silences/` and appear in-cluster
as `silences.observability.giantswarm.io`. Check there before reporting one as
new.

The `home-ops-cockpit` dashboard already filters to actionable alerts, so when
it disagrees with a raw Prometheus query, check this distinction before
concluding the panel is wrong.

During a node reboot that moves a Ceph mgr pod, expect a brief window where
rook-ceph alert annotations render as the literal text "error expanding
template" and `PrometheusRuleFailures` fires. Both mgr pods are scraped while
the old one terminates, the duplicated `ceph_*_metadata` series make the
rules' `group_left` joins many-to-many, and evaluation plus the annotations'
inline template queries fail together. Observed on the 2026-08-06 Talos
rollout; it self-heals when the stale scrape target drops. Confirm with
`prometheus_rule_evaluation_failures_total` returning to zero rather than
treating the garbled alert text as new breakage; it is upstream rule
fragility, not a local rule error.

## Per-change heuristics

- Workflow or tooling changes: run the formatting and workflow checks above,
  and inspect the affected GitHub Actions logic.
- App changes: app-level `kubectl kustomize`, cluster render with Flate, and an
  image diff when image refs may change.
- Storage or backup changes: identify affected PVCs and backup objects before
  editing, then document restore testing.
- Operator or CRD changes: keep the pull request narrow and include the reason
  the new component is needed.
- Docs-only changes: do not run cluster validation unless the docs changed
  commands or operational instructions.

## CI and tooling boundaries

CI runs tools directly. Do not route everything through `just`.

`just` is for local/operator workflows: diagnostics, rendering helpers, live
cluster actions, bootstrap, Talos, and restore operations. Changes to Justfiles
are formatted by Lefthook. Image Pull currently filters on `kubernetes/**/*`,
so changes under `kubernetes/` can trigger it even when the touched file is
local/operator tooling rather than rendered cluster state.

The `Chart Verify` workflow runs on pull requests that touch an
`ocirepository.yaml`: it re-runs cosign at the new pinned tag under each
changed manifest's own identity regexes, and fails when a `verify` block is
removed or its identity changed unless the pull request carries the
`verify/declared` label. It is advisory, not a required check, and it
reads only public registries and Sigstore. Read its annotations before
merging a chart bump it flags; a signer that changed is a policy decision
under ADR-0003, never a regex to loosen.

The `Render` workflow is a GitHub-hosted post-merge alarm, not a required pull
request check. It runs Flate on `main` after changes under `kubernetes/` so
merge trains can stay lightweight while the applied branch still gets rendered.
Konflate remains the pull request render and diff gate. Render's failures are
silent unless watched, and post-merge breakage also surfaces through Flux
alerts to Alertmanager.

`mise` owns the repo-local environment and toolchain contract. Use it for
environment variables, project-specific tool installation, and reproducible
tool activation. When a required repo tool might not be on `PATH`, prefer
`mise exec -- <tool> <args>`. Wrap a repeated invocation in a shell function,
never a string variable: zsh does not word-split `$K` in command position, so
`K="mise exec -- kubectl"; $K get pods` fails there and only works in bash by
accident.

Worktree caveat: mise's `[env]` resolves paths like `KUBECONFIG` against
`config_root`, which in a git worktree is the worktree itself — where
untracked credential files such as `kubeconfig` do not exist. Cluster reads
from a worktree need the path spelled out (`--kubeconfig` or an explicit
`KUBECONFIG` pointing at the main checkout).

Keep personal workstation preferences, shell/editor configuration, auth state,
and user-specific tools in dotfiles rather than this repo. Do not store
secrets, session state, kubeconfig, talosconfig, or 1Password material in mise
config.

Do not move live-cluster or restore recipes from `just` to mise tasks. Mise
tasks may be useful later for small, non-mutating validation aliases, but add
them only when they reduce duplication and do not blur the operator safety
boundary.

The committed `.mise/mise.lock` pins per-platform checksums, URLs, and
provenance for every tool; `mise install` verifies against it locally and in
CI. The shared lefthook `mise-lock` hook refreshes it on any local commit
touching the mise config. Renovate updates the lock alongside tool bumps on
freshly rebased branches; a mise PR created before the lockfile landed
updates only the config, leaving the lock behind until the next refresh —
rebase such PRs rather than merging them stale.

## Bypass merges

Use a bypass merge only when a cluster outage or cluster-hosted automation
failure prevents `Konflate` or `Image Pull` from reporting. Do not use it to
skip a check that reported a real repository, render, image, or workflow
failure.

Before bypassing, validate the smallest relevant set locally:

```sh
mise exec -- flate test all -p ./kubernetes/flux/cluster --allow-missing-secrets
mise exec -- flate diff images -p ./kubernetes/flux/cluster -o json
```

For workflow or Renovate configuration changes, also run the formatting and
workflow checks above. In the pull request or merge note, record why the bypass
was needed and which local commands passed. After merging, watch the
GitHub-hosted `Render` alarm and Flux reconciliation for the merged revision.

Docs-only direct-to-main commits require the repo-admin ruleset bypass — they
skip both the pull-request requirement and the required checks — and are for
low-risk changes with explicit approval. They need only
`oxfmt --check` locally and no cluster validation, matching the docs-only
change heuristic; note the bypass in the commit or the session record.
