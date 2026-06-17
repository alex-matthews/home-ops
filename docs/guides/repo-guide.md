# Repo Guide

This is a compact map for this GitOps repo's layout, app patterns, and validation
commands. Agent behavior and change-control rules live in
[`../../AGENTS.md`](../../AGENTS.md).

## Reference Repos

Use these as design references, not sources to copy blindly:

- [onedr0p/home-ops](https://github.com/onedr0p/home-ops)
- [buroa/k8s-gitops](https://github.com/buroa/k8s-gitops)
- [bjw-s-labs/home-ops](https://github.com/bjw-s-labs/home-ops)

Prefer this repo's existing layout and conventions when they differ.
When a task is modeled on a reference repo, compare the relevant files or PRs
before editing. Treat unexplained divergence from onedr0p/home-ops or
buroa/k8s-gitops as something to call out before implementation, especially for
GitHub Actions, Flux/Konflate/Flate, chart migrations, storage, and ingress.

## Layout

- `.github/workflows/`: CI, Renovate Research Review, label sync, Renovate, and
  tag automation.
- `.agents/instructions/`: narrow reusable agent instructions, currently YAML
  ordering.
- `bootstrap/`: one-time cluster bootstrap helpers.
- `docs/`: durable documentation, including ADRs, guides, and operations docs.
- `kubernetes/apps/`: Flux-managed application declarations.
- `kubernetes/components/`: reusable Kustomize components, including SOPS,
  VolSync, and zeroscaler.
- `kubernetes/flux/cluster`: top-level Flux cluster entrypoint used by Flate.
- `kubernetes/mod.just`: local/operator Kubernetes commands, not CI validation
  glue.
- `talos/`: Talos machine config templates and local helpers.
- `volsync/`: local/operator restore templates and workflows.

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
- Kopiur repository, policy, schedule, restore, and PVC populator wiring.
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
oxfmt --check .
actionlint .github/workflows/*.yaml
zizmor --offline .github/workflows/*.yaml
```

Flux and Kubernetes rendering:

```sh
flate test all -p ./kubernetes/flux/cluster --allow-missing-secrets
```

Image diff for Kubernetes app changes:

```sh
flate diff images -p ./kubernetes/flux/cluster -o json
```

For a quick Kustomize-only smoke test, render the touched namespace or app
directory when possible:

```sh
kubectl kustomize kubernetes/apps/<namespace>/<app>/app
```

## Tooling Boundaries

CI runs tools directly. Do not route everything through `just`.

`just` is for local/operator workflows: diagnostics, rendering helpers, live
cluster actions, bootstrap, Talos, and restore operations. Changes to Justfiles
are formatted by Lefthook. Flate and Image Pull currently filter on
`kubernetes/**/*`, so changes under `kubernetes/` can trigger those workflows
even when the touched file is local/operator tooling rather than rendered
cluster state.

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

- For workflow/tooling changes, validate with `oxfmt`, `actionlint`, `zizmor`,
  and the affected GitHub Actions logic.
- For app changes, validate with app-level `kubectl kustomize`, cluster Flate,
  and image diff when image refs may change.
- For storage or backup changes, identify affected PVCs and backup objects
  before editing, then document restore testing.
- For operator or CRD changes, make the PR narrow and include the reason the new
  component is needed.
- For docs-only changes, do not run cluster validation unless the docs changed
  commands or operational instructions.
