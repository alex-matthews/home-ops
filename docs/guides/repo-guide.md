# Repo Guide

This is a compact map for making safe changes in this GitOps repo. Prefer the
patterns already present here over introducing new structure.

## Reference Repos

Use these as design references, not sources to copy blindly:

- [onedr0p/home-ops](https://github.com/onedr0p/home-ops)
- [buroa/k8s-gitops](https://github.com/buroa/k8s-gitops)
- [home-operations/cluster-template](https://github.com/home-operations/cluster-template)

Prefer this repo's existing layout and conventions when they differ.
When a task is modeled on a reference repo, compare the relevant files or PRs
before editing. Treat unexplained divergence from onedr0p/home-ops or
buroa/k8s-gitops as something to call out before implementation, especially for
GitHub Actions, Flux/Konflate/Flate, chart migrations, storage, and ingress.

## Layout

- `.github/workflows/`: CI, label sync, Renovate, and tag automation.
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

`backlog.md`, if present in a working tree, is scratch state. Do not treat it as
durable repo documentation or commit it unless the user explicitly changes that
policy.

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
- `persistence`
- `resources`
- `securityContext`

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

If a change touches storage or backups, prefer a plan-first pass and include a
restore or rollback validation path.

## Change Control

For infra, workflow, GitOps, and automation work, write down the intended diff,
reference-repo comparison, validation plan, and acceptance criteria before
editing unless the user explicitly asks for immediate implementation.

Do not introduce bespoke scripts, provider systems, permissions, webhooks,
storage, auth surfaces, public routes, or new external services without explicit
justification and approval. If the change diverges from a reference repo, say
why first.

Use PR branches for high-risk changes unless the user explicitly approves
direct-to-main edits. If live verification shows unexpected behavior, stop and
report the result before layering more changes. When finishing, summarize what
changed, what passed validation, and any remaining gap or risk.

## Validation

Use the smallest relevant set.

Formatting and workflow checks:

```sh
oxfmt --check .
zizmor --offline .github/workflows/*.yaml
```

Flux and Kubernetes rendering:

```sh
kubectl kustomize kubernetes/apps/flux-system
flate test all --allow-missing-secrets
```

Image diff for Kubernetes app changes:

```sh
FLATE_BASE=main FLATE_OUTPUT=json flate diff images
```

For a specific app, render its `app/` directory when possible:

```sh
kubectl kustomize kubernetes/apps/<namespace>/<app>/app
```

## Tooling Boundaries

CI runs tools directly. Do not route everything through `just`.

`just` is for local/operator workflows: diagnostics, rendering helpers, live
cluster actions, bootstrap, Talos, and restore operations. Changes to Justfiles
are formatted by Lefthook, but `kubernetes/mod.just` is intentionally excluded
from Flate/Image Pull change filters because it is not part of the render path.

`mise` is used for environment variables and tool installation support. Do not
add mise tasks unless explicitly requested.

## Change Heuristics

- For workflow/tooling changes, validate with `oxfmt`, `zizmor`, and the
  affected GitHub Actions logic.
- For app changes, validate with app-level `kubectl kustomize`, cluster Flate,
  and image diff when image refs may change.
- For storage or backup changes, identify affected PVCs and backup objects
  before editing, then document restore testing.
- For operator or CRD changes, make the PR narrow and include the reason the new
  component is needed.
- For docs-only changes, do not run cluster validation unless the docs changed
  commands or operational instructions.
