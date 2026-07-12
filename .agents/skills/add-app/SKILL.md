---
name: add-app
description: Scaffold a new Flux-managed application under kubernetes/apps/ — chart selection, manifests, registration, validation. Use when deploying a new app or service to the cluster.
---

# Add a New Application

Scaffolds `kubernetes/apps/<namespace>/<app>/` with a Flux Kustomization and a
HelmRelease (chart chosen in Step 0). Every value below comes from current
repo conventions. When in doubt, mirror a real app instead of inventing
structure:

| Reference app                       | Shows                                                                                       |
| ----------------------------------- | ------------------------------------------------------------------------------------------- |
| `kubernetes/apps/default/atuin`     | Small app: internal route, VolSync-backed PVC, no secrets                                   |
| `kubernetes/apps/default/recyclarr` | Config files via `configMapGenerator` + `resources/`                                        |
| `kubernetes/apps/default/resolute`  | ExternalSecret, SOPS-encrypted config Secret, ServiceMonitor, CronJob, single-writer SQLite |
| `kubernetes/apps/default/plex`      | Public route on `envoy-external`, Gatus endpoint annotation, LoadBalancer service           |

## Step 0: Pick the chart

If the app has a maintained upstream chart or a home-operations chart, use
that chart instead of app-template: mirror an existing upstream-chart app such
as `kubernetes/apps/default/chaski` or
`kubernetes/apps/observability/gatus-sidecar`, follow the chart's own values
order, and skip the app-template specifics below.

The rest of this skill covers the common case for self-hosted apps: a
container image with no maintained chart, deployed via bjw-s app-template.

## Step 1: Gather details

Confirm with the user anything not already given:

1. **App name** and **namespace** (existing: `ls kubernetes/apps/`). A new
   namespace is rare; if needed, copy an existing namespace directory's
   `namespace.yaml` and `kustomization.yaml` shape.
2. **Image** repository and tag. Pin as `tag@sha256:digest`; Renovate maintains
   it afterward.
3. **Port**, and the route posture: none, internal (`envoy-internal`, the
   default), or public (`envoy-external` — public routes need explicit
   justification per `AGENTS.md`).
4. **Persistence**: stateful apps get their PVC from the VolSync component,
   which also wires backups and requires the Rook-Ceph dependency.
5. **Secrets**: an ExternalSecret sourced from 1Password. Get the exact item
   and field names; never guess them.
6. **Config files**: mounted config uses `configMapGenerator` plus a
   `resources/` directory (see recyclarr). Config carrying household identity
   or other sensitive values goes into a SOPS-encrypted Secret instead (see
   resolute's `secret.sops.yaml`).
7. **Dependencies**: other Flux Kustomizations this app needs (`dependsOn`).

## Step 2: Create the files

```text
kubernetes/apps/<namespace>/<app>/
├── ks.yaml
└── app/
    ├── kustomization.yaml
    ├── ocirepository.yaml
    ├── helmrelease.yaml
    ├── externalsecret.yaml   # only with secrets
    └── resources/            # only with config files
```

### ks.yaml

Copy atuin's `ks.yaml`. Keep the key order and drop what does not apply:

- `components` + `dependsOn` (rook-ceph-cluster): only with a VolSync PVC.
- `postBuild.substitute.APP` is required by the VolSync component; add
  `VOLSYNC_CAPACITY` when the component default (5Gi) is wrong.
- `postBuild.substituteFrom: cluster-secrets`: needed for `${SECRET_DOMAIN}`
  and other substituted values.
- `targetNamespace` matches the namespace directory.

### app/kustomization.yaml

Copy atuin's. Resources are listed alphabetically. With config files, copy
recyclarr's `configMapGenerator` block (name `<app>-configmap`, one entry per
`resources/` file, `disableNameSuffixHash: true`).

### app/ocirepository.yaml

Copy atuin's. The chart is `oci://ghcr.io/bjw-s-labs/helm/app-template`; use
the same chart tag as nearby apps (Renovate bumps it).

### app/helmrelease.yaml

Copy atuin's and adapt. Invariants to keep:

- Schema comment pointing at the app-template helmrelease schema.
- `spec.values` order: `controllers`, `defaultPodOptions`, `service`, `route`,
  `configMaps`, `persistence` (see
  `.agents/instructions/yaml-ordering.instructions.md`).
- `defaultPodOptions.securityContext` for VolSync-backed apps only:
  `runAsNonRoot: true`, `runAsUser: 1032`, `runAsGroup: 100`, `fsGroup: 100`,
  `fsGroupChangePolicy: OnRootMismatch` — the identity the Restic movers and
  the NAS convention expect (`docs/operations/storage-and-backups.md`). Apps
  without VolSync persistence run whatever identity their image expects; keep
  `runAsNonRoot: true` where the image allows it.
- Container `securityContext`: `allowPrivilegeEscalation: false`,
  `readOnlyRootFilesystem: true`, `capabilities: { drop: ["ALL"] }`. Add an
  `emptyDir` at `/tmp` if the app needs scratch space (see resolute).
- Liveness, readiness, and startup probes like atuin; use a custom `httpGet`
  readiness probe when the app has a health endpoint.
- `resources`: `requests.cpu: 10m` and a memory limit sized to the app.
- Route hostnames use `"{{ .Release.Name }}.${SECRET_DOMAIN}"`; never hardcode
  the domain. Public routes get a Gatus endpoint annotation (see plex).
- VolSync persistence mounts `existingClaim: "{{ .Release.Name }}"`.
- Config files mount as `type: configMap` with
  `name: "{{ .Release.Name }}-configmap"` (see recyclarr); SOPS-encrypted
  config mounts as `type: secret` (see resolute).
- Secrets arrive via `envFrom` from `"{{ .Release.Name }}-secret"`, with
  `reloader.stakater.com/auto: "true"` on the controller.
- SQLite or other single-writer apps: `replicas: 1` with
  `strategy: Recreate`, and a comment saying not to scale (see resolute).

### app/externalsecret.yaml

Copy the first document in resolute's `externalsecret.yaml` (the file holds a
second, scoped ExternalSecret for its CronJob — most apps need only one):
`ClusterSecretStore` `onepassword-connect`, a `target.template.data` map from
1Password fields to the env names the app expects, and `dataFrom.extract` per
1Password item.

## Step 3: Register the app

Add `./<app>/ks.yaml` to `kubernetes/apps/<namespace>/kustomization.yaml`,
keeping the list alphabetical.

## Step 4: Validate

```sh
mise exec -- kubectl kustomize kubernetes/apps/<namespace>/<app>/app
mise exec -- flate test all -p ./kubernetes/flux/cluster --allow-missing-secrets
mise exec -- flate diff images -p ./kubernetes/flux/cluster -o json
mise exec --no-deps -- oxfmt --check <changed files>
```

The image diff should list exactly the new app's image. Open the change as a
PR branch; Konflate posts the rendered diff on the PR.
