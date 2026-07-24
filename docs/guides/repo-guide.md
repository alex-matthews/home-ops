# Repo Guide

This is a compact map for this GitOps repo's layout, app patterns, and validation
commands. Agent behavior and change-control rules live in
[`../../AGENTS.md`](../../AGENTS.md).

## Layout

- `.agents/instructions/`: narrow reusable agent instructions such as YAML
  ordering and GitHub linking.
- `.agents/skills/`: task recipes such as `add-app` and `audit-findings`.
- `.github/actionlint.yaml`: actionlint configuration.
- `.github/labels.yaml`: label definitions synced by CI.
- `.github/workflows/`: Lint, Image Pull, the post-merge Render alarm,
  Renovate, Renovate PR Review, and Label Sync.
- `.mise/config.toml`: repo-pinned tool versions and local environment.
- `.renovaterc.json5`: Renovate configuration.
- `bootstrap/`: one-time cluster bootstrap helpers.
- `docs/`: durable documentation, including ADRs, guides, and operations docs.
- `kubernetes/apps/`: Flux-managed application declarations.
- `kubernetes/components/`: reusable Kustomize components, including alerts,
  Dragonfly, SOPS, VolSync, and zeroscaler.
- `kubernetes/flux/cluster`: top-level Flux cluster entrypoint used by render
  tooling.
- `kubernetes/mod.just`: local/operator Kubernetes commands, not CI validation
  glue.
- `talos/`: Talos machine config templates and local helpers.
- `volsync/`: local/operator restore templates and workflows.

## How the Cluster Works

How a merged change reaches the cluster:

1. Flux follows `main` through the `flux-system` `GitRepository` managed by
   Flux Operator.
2. `kubernetes/flux/cluster/ks.yaml` defines the `cluster-apps` Kustomization.
   It reconciles `./kubernetes/apps`, enables SOPS decryption, and patches
   every child Kustomization with the same decryption and HelmRelease
   remediation defaults.
3. Each namespace directory's `kustomization.yaml` creates the Namespace, adds
   the shared alerts component (all namespaces) and the SOPS component (only
   namespaces that need `cluster-secrets`), and lists every app `ks.yaml`.
4. Each app `ks.yaml` is a Flux Kustomization that renders the app's `app/`
   directory into the target namespace.

Nothing reaches the cluster except through this path. Imperative changes are
diagnostics-only; Flux overwrites drift on the next reconcile.

Secrets reach workloads through three mechanisms; pick by data shape:

- Ordinary runtime credentials (API keys, passwords, tokens): 1Password →
  onepassword-connect → the `onepassword-connect` `ClusterSecretStore` → a
  per-app `ExternalSecret` → a Kubernetes Secret the workload consumes via
  `envFrom` or `env`. This is the default for anything credential-shaped;
  secret material never appears in Git.
- Build-time substitution for non-credential values: the SOPS component ships
  an age-encrypted `cluster-secrets` Secret into the namespaces that include
  the component — not all do. App `ks.yaml` files opt in with
  `postBuild.substituteFrom: cluster-secrets`, which fills
  `${SECRET_DOMAIN}`-style placeholders when Flux builds the app.
- Exception for indivisible structured files: a config file that mixes
  sensitive and non-sensitive content and cannot cleanly split into
  ExternalSecret fields may be committed as a directly SOPS-encrypted Secret
  in the app directory and mounted as a file (resolute's `secret.sops.yaml`
  household policy is the one current example). Do not use this path for
  ordinary credentials; those belong in 1Password.

Backup posture is chosen from an app's value and recovery requirements, not
from the presence of a PVC. Protected application state — the norm in the
`default` namespace — currently gets its PVC from the compatibility VolSync
component (`kubernetes/components/volsync`), which composes separately
selectable `backup` and `restore` concerns: a `${APP}` claim on `ceph-block`
with a restore-capable `dataSourceRef`, an hourly local Restic
`ReplicationSource`, and a daily remote one. The `restore/remote` override
retargets the same restore wiring to the remote repository for disaster
recovery. The prepared Kopiur `restore` component provides the passive
Restore/PVC population path for the approved cutover. Some persistent
workloads, notably observability storage, intentionally use plain PVCs with no
VolSync coverage. Backup topology and restore criteria live in
[`../operations/storage-and-backups.md`](../operations/storage-and-backups.md);
restore templates live under `volsync/`.

VolSync-backed apps run as `runAsUser: 1032` / `runAsGroup: 100` /
`fsGroup: 100`, matching their Restic movers and the NAS-side convention;
other apps run whatever identity their image expects. Do not change a
backed-up app's identity without migrating PVC ownership in the same window.

Stateful apps here are conventionally single-replica (the chart default; most
set no explicit `replicas` or `strategy`). Their `ReadWriteOnce` PVCs bind
read/write mounting to a single node, which constrains scheduling and rolling
updates across nodes — but RWO does not prevent multiple pods on that node
from sharing the volume and is not a single-writer guarantee (Kubernetes has
`ReadWriteOncePod` for that). resolute's stricter rule is application-level:
its SQLite database allows one writer, so it pins `replicas: 1` with
`strategy: Recreate`, routes writes through the one API pod, and must never
be scaled. That constraint comes from the app, not from RWO or any
cluster-wide rule.

## App Pattern

Most applications follow:

```text
kubernetes/apps/<namespace>/<app>/ks.yaml
kubernetes/apps/<namespace>/<app>/app/kustomization.yaml
kubernetes/apps/<namespace>/<app>/app/helmrelease.yaml
kubernetes/apps/<namespace>/<app>/app/ocirepository.yaml
```

Common additions are `externalsecret.yaml`, `pvc.yaml`, `httproute.yaml`,
`servicemonitor.yaml`, dashboards, alerts, or app-specific config files.

Some apps intentionally split related resources into sibling directories such as
`config/`, `crds/`, `collector/`, `cluster/`, `dashboards/`, `instance/`,
`runners/`, `silences/`, or `upgrades/`. Follow the parent `ks.yaml` and
`kustomization.yaml` wiring before flattening a layout or introducing a new one.

The namespace-level `kustomization.yaml` includes each app `ks.yaml`. The app
`ks.yaml` points Flux at the `app/` directory, usually sets `targetNamespace`,
adds `postBuild.substituteFrom` for `cluster-secrets`, and declares dependencies
such as Rook-Ceph when needed.

Prefer existing bjw-s app-template values for app workloads:

- `controllers`
- `defaultPodOptions`
- `service`
- `route`
- `configMaps`
- `persistence`

Use existing image, route, probe, security, and persistence patterns from nearby
apps before adding a new style.

## Sensitive Surfaces

Treat these as high-risk:

- `*.sops.yaml` files: do not reformat or reshape encrypted content.
- `ExternalSecret` names, target secret names, and template keys.
- PVC names, storage classes, access modes, and `dataSourceRef` fields.
- VolSync `ReplicationSource` and `ReplicationDestination` objects.
- Kopiur repository, policy, schedule, restore, and PVC populator wiring
  (pilot live under `kubernetes/apps/default/bazarr/backup/` and
  `kubernetes/apps/kopiur-system/`).
- Backup retention, schedule, copy method, repository secret, and restore wiring.
- Rook-Ceph, Cilium, Flux, External Secrets, and cert-manager CRDs.
- Namespace names and app names used by Flux, HelmRelease, alerts, dashboards, or
  backup components.
- Hostnames in manifests, durable docs, rules files, or workflow defaults.
  Prefer manifest substitution such as `${SECRET_DOMAIN}`, or existing repo
  secrets/vars such as `KONFLATE_URL`, instead of hardcoding hostnames. CI,
  workflow logs, generated comments, and status-check links may expose
  configured public hostnames when that is the practical integration shape; do
  not treat that exposure as a blocker by itself.

If a change touches storage or backups, prefer a plan-first pass and include a
restore or rollback validation path.

## YAML Ordering

When editing YAML, preserve the repo's established ordering instead of blindly
sorting every key. For reusable ordering rules, see
[`../../.agents/instructions/yaml-ordering.instructions.md`](../../.agents/instructions/yaml-ordering.instructions.md).

If nearby manifests use a chart-specific order, follow the nearby pattern unless
that conflicts with the reusable ordering rules.

## Validation

Use the smallest relevant set.

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

## Issue and PR Writing

When referencing an issue or PR in another repository, use backlink-safe link
forms so this public repository does not emit cross-reference events into
upstream timelines. See
[`../../.agents/instructions/github-linking.instructions.md`](../../.agents/instructions/github-linking.instructions.md).

## Tooling Boundaries

CI runs tools directly. Do not route everything through `just`.

`just` is for local/operator workflows: diagnostics, rendering helpers, live
cluster actions, bootstrap, Talos, and restore operations. Changes to Justfiles
are formatted by Lefthook. Image Pull currently filters on `kubernetes/**/*`, so
changes under `kubernetes/` can trigger it even when the touched file is
local/operator tooling rather than rendered cluster state.

The `Render` workflow is a GitHub-hosted post-merge alarm, not a required pull
request check. It runs Flate on `main` after changes under `kubernetes/` so
merge trains can stay lightweight while the applied branch still gets rendered.
Konflate remains the pull request render and diff gate. Render's failures are
silent unless watched, and post-merge breakage also surfaces through Flux
alerts to Alertmanager; whether Render stays is tracked in
[#1560](https://github.com/alex-matthews/home-ops/issues/1560).

### Bypass Merges

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
workflow checks from the validation section. In the PR or merge note, record why
the bypass was needed and which local commands passed. After merging, watch the
GitHub-hosted `Render` alarm and Flux reconciliation for the merged revision.

Docs-only direct-to-main commits (allowed for low-risk changes with explicit
approval, per AGENTS.md) also bypass the required checks. They need only
`oxfmt --check` locally and no cluster validation, matching the docs-only
change heuristic; note the bypass in the commit or the session record.

`mise` owns the repo-local environment and toolchain contract. Use it for
environment variables, project-specific tool installation, and reproducible
tool activation. When a required repo tool might not be on `PATH`, prefer:

```sh
mise exec -- <tool> <args>
```

Keep personal workstation preferences, shell/editor configuration, auth state,
and user-specific tools in dotfiles rather than this repo. Do not store secrets,
session state, kubeconfig, talosconfig, or 1Password material in mise config.

Do not move live-cluster or restore recipes from `just` to mise tasks. Mise
tasks may be useful later for small, non-mutating validation aliases, but add
them only when they reduce duplication and do not blur the operator safety
boundary.

If this repo adopts a committed `mise.lock`, treat it as a reproducibility and
supply-chain decision. Renovate can update mise config and lockfiles, but
lockfile refresh requires running `mise lock`, so enable that only after the
Renovate execution model has been reviewed.

## Change Heuristics

- For workflow/tooling changes, validate with the formatting/workflow checks
  above and inspect the affected GitHub Actions logic.
- For app changes, validate with app-level `kubectl kustomize`, cluster render
  with Flate, and image diff when image refs may change.
- For storage or backup changes, identify affected PVCs and backup objects
  before editing, then document restore testing.
- For operator or CRD changes, make the PR narrow and include the reason the new
  component is needed.
- For docs-only changes, do not run cluster validation unless the docs changed
  commands or operational instructions.

## Reference Repos

Use peer repositories to answer a narrow question: "how have others solved this
specific problem?" They are comparison inputs, not constraints. Before adopting a
pattern, inspect the relevant current files or PRs and call out material
differences from this repo.

Common non-goals:

- Do not copy public routes, domains, OIDC setup, broad RBAC, storage classes,
  UID/GID values, backup cadence, or branch protection rules from peers.
- Do not add gateway/federation pieces, stateful memory/search substrates,
  local inference, or helper CLIs before a local consumer needs them.
- Do not treat peer CI status names as this repo's branch-protection truth.

### Start Here

- GitOps shape: [onedr0p/home-ops], [buroa/k8s-gitops],
  [bjw-s-labs/home-ops].
- AI workbench and MCP: [bjw-s-labs/home-ops], [eleboucher/homelab],
  [m00nwtchr/homelab-cluster], [perryhuynh/homelab].
- Compact agent guidance: [Tanguille/cluster], [bjw-s-labs/home-ops].
- Renovate AI review: [joryirving/home-ops], [bo0tzz/clusterfuck],
  [misospace/pr-reviewer-action], [koki-develop/claude-renovate-review].
- Kopiur and backup migration: [home-operations/kopiur],
  [buroa/k8s-gitops], [onedr0p/home-ops], [eleboucher/homelab].

### Domain Catalog

- Lean GitOps and app shape: use [onedr0p/home-ops], [buroa/k8s-gitops],
  [bjw-s-labs/home-ops], and [perryhuynh/homelab] for app-template idioms,
  Kustomize component shape, Image Pull/Flate posture, and namespace/app layout.
- Render and CI posture: use [onedr0p/home-ops], [waifulabs/infrastructure],
  [Tanguille/cluster], [jfroy/flatops], [auricom/home-ops], and
  [rcdailey/home-ops] for workflow scoping, render checks, and report shape.
- AI workbench architecture: use [bjw-s-labs/home-ops],
  [eleboucher/homelab], and [m00nwtchr/homelab-cluster] for Hermes, ToolHive,
  LiteLLM, Memini, OpenClaw, embeddings/reranking, and workbench composition.
- MCP and ToolHive patterns: use [bjw-s-labs/home-ops],
  [eleboucher/homelab], [perryhuynh/homelab], [rafaribe/home-ops], and
  [jfroy/flatops] for MCPGroup/vMCP shape, internal routes, read-only infra
  MCPs, and per-tool examples.
- Agentgateway and provider routing: use [perryhuynh/homelab],
  [m00nwtchr/homelab-cluster], and [joryirving/home-ops] for future
  agentgateway, Gateway API, provider routing, and model-routing references.
- Model gateway and routing: use [bjw-s-labs/home-ops], [eleboucher/homelab],
  [joryirving/home-ops], and [Tanguille/cluster] for LiteLLM aliases, model
  tiers, fallback/smart routing, metrics, and reviewer routing.
- Memory, search, and reranking: use [eleboucher/homelab],
  [bjw-s-labs/home-ops], [m00nwtchr/homelab-cluster], and [rafaribe/home-ops]
  for Memini, memory MCPs, embeddings, TEI/reranker, and SearXNG/search
  candidates.
- Agent guidance and public safety: use [Tanguille/cluster],
  [bjw-s-labs/home-ops], [jfroy/flatops], [auricom/home-ops], and
  [rcdailey/home-ops] for compact AGENTS.md shape, on-demand `.agents/`
  guidance, Flux/MCP safety, public-repo guardrails, and cautionary large
  manuals.
- Renovate AI review: use [bo0tzz/clusterfuck], [joryirving/home-ops],
  [Tanguille/cluster], [billimek/k8s-gitops], [wrmilling/k3s-gitops],
  [misospace/pr-reviewer-action], and [koki-develop/claude-renovate-review] for
  upgrade research rubric, wrapper/upstream changelog tracing, rendered
  evidence inputs, re-review/fingerprint behavior, model tiers, and cost/status
  visibility.
- Toolchain and local workflow: use [Tanguille/cluster],
  [bjw-s-labs/home-ops], [auricom/home-ops], and [rcdailey/home-ops] for
  `mise exec --`, task/just boundaries, pre-commit/formatting posture, and local
  operator workflow shape.
- Docs surface: use [Tanguille/cluster], [jfroy/flatops],
  [waifulabs/infrastructure], and [rcdailey/home-ops] for minimal durable docs,
  compact runbooks, and docs-site examples as contrast.
- Kopiur adoption: use [home-operations/kopiur], [buroa/k8s-gitops],
  [eleboucher/homelab], and [onedr0p/home-ops] for ClusterRepository, mover
  defaults, credential projection, SnapshotPolicy/SnapshotSchedule, passive
  Restore, and PVC populator shape.
- VolSync and restore caution: use [bo0tzz/clusterfuck],
  [carpenike/k8s-gitops], and [Pumba98/flux2-gitops] for VolSync restore docs,
  one-shot restore gates, shared-PVC caution, and `dataSourceRef` immutability.

[auricom/home-ops]: https://github.com/auricom/home-ops
[billimek/k8s-gitops]: https://github.com/billimek/k8s-gitops
[bjw-s-labs/home-ops]: https://github.com/bjw-s-labs/home-ops
[bo0tzz/clusterfuck]: https://github.com/bo0tzz/clusterfuck
[buroa/k8s-gitops]: https://github.com/buroa/k8s-gitops
[carpenike/k8s-gitops]: https://github.com/carpenike/k8s-gitops
[eleboucher/homelab]: https://github.com/eleboucher/homelab
[home-operations/kopiur]: https://github.com/home-operations/kopiur
[jfroy/flatops]: https://github.com/jfroy/flatops
[joryirving/home-ops]: https://github.com/joryirving/home-ops
[koki-develop/claude-renovate-review]: https://github.com/koki-develop/claude-renovate-review
[m00nwtchr/homelab-cluster]: https://github.com/m00nwtchr/homelab-cluster
[misospace/pr-reviewer-action]: https://github.com/misospace/pr-reviewer-action
[onedr0p/home-ops]: https://github.com/onedr0p/home-ops
[perryhuynh/homelab]: https://github.com/perryhuynh/homelab
[Pumba98/flux2-gitops]: https://github.com/Pumba98/flux2-gitops
[rafaribe/home-ops]: https://github.com/rafaribe/home-ops
[rcdailey/home-ops]: https://github.com/rcdailey/home-ops
[Tanguille/cluster]: https://github.com/Tanguille/cluster
[waifulabs/infrastructure]: https://github.com/waifulabs/infrastructure
[wrmilling/k3s-gitops]: https://github.com/wrmilling/k3s-gitops
