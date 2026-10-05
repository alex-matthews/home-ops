# Repository Layout and App Pattern

Verified 2026-10-05 against the repository at `main`.

Where things live and what shape an app takes. Follow the app's `ks.yaml` to
its source directory and nearby patterns.
[Architecture](../../../../ARCHITECTURE.md#from-a-commit-to-a-workload)
explains components and parent patches; [validation](../../../../CONTRIBUTING.md#validate-locally)
covers the checks.

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
Single-writer apps need one replica and `Recreate`; app-template 5.2.1
[defaults](https://redirect.github.com/bjw-s-labs/helm-charts/blob/app-template-5.2.1/charts/library/common/templates/classes/_deployment.tpl)
can supply them. Verify effective values; never scale above one. Stopping
them follows [maintenance](../../maintenance-window/SKILL.md).

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
