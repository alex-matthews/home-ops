# Repository Layout and App Pattern

Verified 2026-10-05 against the repository at `main`.

Where things live and what shape an app takes. Follow the app's `ks.yaml` to
its source directory and nearby patterns.
[Architecture](../../../../ARCHITECTURE.md#from-a-commit-to-a-workload)
explains components and parent patches; [validation](../../../../CONTRIBUTING.md#validate-locally)
covers the checks.

## Contents

- [Layout](#layout)
- [App shape](#app-shape)
- [Flux Kustomization](#flux-kustomization)
- [app-template HelmRelease](#app-template-helmrelease)
- [Secrets and substitution](#secrets-and-substitution)
- [Persistent state and migrations](#persistent-state-and-migrations)
- [YAML ordering](#yaml-ordering)

## Layout

- `.agents/skills/`: task recipes, each with its own `references/`.
- `.github/scripts/`: the bash scripts CI runs, with their offline fixtures
  under `.github/tests/`.
- `.github/workflows/`: CI, described in
  [architecture](../../../../ARCHITECTURE.md#what-ci-proves).
- `.mise/`: repo-pinned tools and local environment: `config.toml` (tools
  plus the default read-only identities), `config.admin.toml` (administrative
  profile) and `mise.lock` (committed checksum lockfile).
- `.renovaterc.json5`: Renovate configuration.
- `bootstrap/`: cold start and full rebuild.
- `docs/`: policy, operations and recovery; [index](../../../../docs/README.md).
- `kubernetes/apps/`: Flux-managed application declarations.
- `kubernetes/components/`: reusable Kustomize components, including alerts,
  Dragonfly, Kopiur, SOPS and zeroscaler.
- `kubernetes/flux/cluster`: top-level Flux cluster entrypoint used by render
  tooling.
- `kubernetes/mod.just`: local/operator Kubernetes commands, not CI glue.
- `talos/`: Talos machine config templates and local helpers.

## App shape

Most applications follow:

```text
kubernetes/apps/<namespace>/<app>/ks.yaml
kubernetes/apps/<namespace>/<app>/app/kustomization.yaml
kubernetes/apps/<namespace>/<app>/app/helmrelease.yaml
kubernetes/apps/<namespace>/<app>/app/ocirepository.yaml
```

Common additions are `externalsecret.yaml`, `pvc.yaml`, `httproute.yaml`,
`servicemonitor.yaml`, dashboards, alerts or app-specific config files. Some
apps split related resources into sibling directories such as `config/`,
`crds/`, `cluster/`, `instance/` or `upgrades/`. Follow the parent `ks.yaml`
and `kustomization.yaml` wiring before flattening a layout or introducing a
new one.

The namespace-level `kustomization.yaml` includes each app `ks.yaml`. The app
`ks.yaml` points Flux at the `app/` directory, usually sets `targetNamespace`,
and declares `dependsOn` only where the [ordering
rule](../../../../docs/policy/decisions.md#reconciliation-ordering) requires
it, which is rare for ordinary apps. Use existing image, route, probe,
security and persistence patterns from nearby apps before adding a new style.

## Flux Kustomization

An app's `ks.yaml` keeps atuin's key order; drop what does not apply:

- `components` (kopiur): only with a Kopiur PVC. Check both repository
  `allowedNamespaces` and the namespace's Kopiur secrets component;
  a new namespace does not inherit these. Expanding access needs approval.
- `postBuild.substitute.APP` is required by the Kopiur component; add
  `PVC_CAPACITY` when the component default (5Gi) is wrong.
- `postBuild.substituteFrom: cluster-secrets`: needed for `${SECRET_DOMAIN}`
  and other substituted values, and it only works in namespaces whose
  `kustomization.yaml` includes the SOPS component (`../../components/sops`) —
  check before copying, because without the component the referenced Secret
  does not exist there and reconciliation fails. Drop the block if the app
  substitutes nothing.
- `targetNamespace` matches the namespace directory.

## app-template HelmRelease

An app-template `helmrelease.yaml` keeps these invariants:

- Schema comment pointing at the app-template helmrelease schema.
- `spec.values` order: `controllers`, `defaultPodOptions`, `service`, `route`,
  `configMaps`, `persistence` (see [YAML ordering](#yaml-ordering)).
- `defaultPodOptions.securityContext` for Kopiur-backed apps only:
  `runAsNonRoot: true`, `runAsUser: 1032`, `runAsGroup: 100`, `fsGroup: 100`,
  `fsGroupChangePolicy: OnRootMismatch` — the identity the Kopiur movers and
  the NAS convention expect; check [mover permissions](../../restore-data/references/app-volumes.md#uidgid-and-mover-permissions). Apps
  without backed-up persistence run whatever identity their image expects; keep
  `runAsNonRoot: true` where the image allows it.
- Container `securityContext`: `allowPrivilegeEscalation: false`,
  `readOnlyRootFilesystem: true`, `capabilities: { drop: ["ALL"] }`. Add an
  `emptyDir` at `/tmp` if the app needs scratch space (see sabnzbd).
- Liveness, readiness, and startup probes like atuin; use a custom `httpGet`
  readiness probe when the app has a health endpoint.
- `resources`: start at `requests.cpu: 10m` with a memory limit sized to the
  app; heavier apps in this repo run `100m`, so match a comparable app rather
  than the minimum. Apps with a meaningful memory footprint also set an
  explicit `requests.memory` below the limit (see the arr stack); match a
  comparable app.
- Route hostnames use `"{{ .Release.Name }}.${SECRET_DOMAIN}"`; never hardcode
  the domain. Public routes get a Gatus endpoint annotation (see plex).
- Kopiur-backed persistence mounts `existingClaim: "{{ .Release.Name }}"`.
- Config files mount as `type: configMap` with
  `name: "{{ .Release.Name }}-configmap"` (see recyclarr); SOPS-encrypted
  config mounts as `type: secret`, as resolute did before its removal:
  `git show 90e3da64^:kubernetes/apps/default/resolute/app/helmrelease.yaml`.
- Secrets arrive via `envFrom` from `"{{ .Release.Name }}-secret"`, with
  `reloader.stakater.com/auto: "true"` on the controller.
- Single-writer apps: see [persistent state](#persistent-state-and-migrations).

## Secrets and substitution

Follow the [secret-selection
policy](../../../../docs/policy/decisions.md#secrets-and-substitution). For
substitution, include the namespace SOPS component and opt the app into
`postBuild.substituteFrom`; its references resolve in that Kustomization's
namespace.

## Persistent state and migrations

Choose coverage by recovery need; follow the [volume
prerequisites](../../restore-data/references/app-volumes.md) for protected
claims and ownership changes. ReadWriteOnce limits nodes, not writers.
Single-writer apps need one replica and `Recreate`; app-template 5.3.0
defaults a Deployment to
[one replica](https://redirect.github.com/bjw-s-labs/helm-charts/blob/app-template-5.3.0/charts/library/common/templates/classes/_deployment.tpl)
and [`Recreate`](https://redirect.github.com/bjw-s-labs/helm-charts/blob/app-template-5.3.0/charts/library/common/templates/lib/deployment/_valuesToObject.tpl).
Verify effective values; never scale above one. Stopping them follows
[maintenance](../../maintenance-window/SKILL.md).

Names consumed by controllers/monitoring/backups, access modes,
`dataSourceRef`, identities, retention, copy methods, repository credentials
and CRDs are migration inputs. Plan changes with restore/rollback evidence.
Route chart trust and exposure changes through
[policy](../../../../docs/policy/decisions.md), then choose
[validation](../../../../CONTRIBUTING.md#validate-locally).

## YAML ordering

Apply these to edited files, respecting more specific nearby patterns and
omitting absent sections. Start with `---` and the established schema comment.
Never reformat SOPS files or sort YAML embedded in string values.

- Resources: `apiVersion`, `kind`, `metadata`, `spec`; metadata: `name`,
  `namespace`, `annotations`, `labels`.
- HelmRelease spec: `chartRef`, `interval`, `dependsOn`, `install`, `upgrade`,
  `postRenderers`, `values`.
- Values follow their chart. Identify app-template by OCI URL/schema, not
  `chartRef.name`: `controllers`, `defaultPodOptions`, `service`, `route`,
  `configMaps`, `persistence`.
- Containers: `image`, `env`, `envFrom`, `args`, probes, `securityContext`,
  `resources`; requests precede limits.
