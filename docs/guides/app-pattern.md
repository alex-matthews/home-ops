# Repository Layout and App Pattern

**When to use:** New app, where a file lives, repository layout, `ks.yaml`, HelmRelease, OCIRepository, kustomization, app-template values, sibling directories.

Where things live and what shape a new app takes. For how a change reaches the
cluster see [`cluster-model.md`](cluster-model.md); for validation commands see
[`validation.md`](validation.md).

## Layout

- `.agents/skills/`: task recipes such as `add-app` and
  `maintenance-window`.
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
  Dragonfly, Kopiur, SOPS, and zeroscaler.
- `kubernetes/flux/cluster`: top-level Flux cluster entrypoint used by render
  tooling.
- `kubernetes/mod.just`: local/operator Kubernetes commands, not CI validation
  glue.
- `talos/`: Talos machine config templates and local helpers.

## App pattern

Most applications follow:

```text
kubernetes/apps/<namespace>/<app>/ks.yaml
kubernetes/apps/<namespace>/<app>/app/kustomization.yaml
kubernetes/apps/<namespace>/<app>/app/helmrelease.yaml
kubernetes/apps/<namespace>/<app>/app/ocirepository.yaml
```

Common additions are `externalsecret.yaml`, `pvc.yaml`, `httproute.yaml`,
`servicemonitor.yaml`, dashboards, alerts, or app-specific config files.

Some apps intentionally split related resources into sibling directories such
as `config/`, `crds/`, `collector/`, `cluster/`, `dashboards/`, `instance/`,
`runners/`, `silences/`, or `upgrades/`. Follow the parent `ks.yaml` and
`kustomization.yaml` wiring before flattening a layout or introducing a new
one.

The namespace-level `kustomization.yaml` includes each app `ks.yaml`. The app
`ks.yaml` points Flux at the `app/` directory, usually sets `targetNamespace`,
adds `postBuild.substituteFrom` for `cluster-secrets`, and declares
`dependsOn` only where the doctrine in
[`cluster-model.md`](cluster-model.md) requires it — rare for ordinary apps.

Prefer existing bjw-s app-template values for app workloads:

- `controllers`
- `defaultPodOptions`
- `service`
- `route`
- `configMaps`
- `persistence`

Use existing image, route, probe, security, and persistence patterns from
nearby apps before adding a new style.

To add an app, use the [`add-app`](../../.agents/skills/add-app/SKILL.md)
skill.

## YAML ordering

Preserve the repo's established ordering instead of blindly sorting every key.
The rules are in [`yaml-ordering.md`](yaml-ordering.md).

If nearby manifests use a chart-specific order, follow the nearby pattern
unless that conflicts with those rules.
