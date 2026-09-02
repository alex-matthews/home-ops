---
name: add-app
description: Scaffold a new Flux-managed application under kubernetes/apps/ — chart selection, manifests, registration, validation. Use when deploying a new app or service to the cluster.
---

# Add a New Application

Scaffolds `kubernetes/apps/<namespace>/<app>/` with a Flux Kustomization and a
HelmRelease (chart chosen in Step 0). Every value below comes from current
repo conventions. When in doubt, mirror a real app instead of inventing
structure:

| Reference app                       | Shows                                                                             |
| ----------------------------------- | --------------------------------------------------------------------------------- |
| `kubernetes/apps/default/atuin`     | Small app: internal route, Kopiur-backed PVC, no secrets                          |
| `kubernetes/apps/default/recyclarr` | Config files via `configMapGenerator` + `resources/`                              |
| `kubernetes/apps/default/plex`      | Public route on `envoy-external`, Gatus endpoint annotation, LoadBalancer service |

## Step 0: Pick the chart

If the app has a maintained upstream chart or a home-operations chart, use
that chart instead of app-template: mirror an existing upstream-chart app such
as `kubernetes/apps/default/chaski` or
`kubernetes/apps/observability/gatus-sidecar` for the OCIRepository and
HelmRelease, and follow the chart's own values order. Everything else in this
skill still applies — layout, `ks.yaml`, registration, and validation; only
the app-template specifics in the helmrelease section do not.

The helmrelease guidance below covers the common case for self-hosted apps: a
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
4. **Persistence**: choose backup posture from the app's value and recovery
   requirements, not from the presence of a PVC. Protected application state
   (the norm in the `default` namespace) uses the Kopiur component, which
   supplies the PVC and its backups.
   Some persistent workloads — observability data especially — intentionally
   use plain PVCs with no backup coverage; do not add coverage just because
   the app is stateful.
5. **Secrets**: an ExternalSecret sourced from 1Password. Get the exact item
   and field names; never guess them.
6. **Config files**: mounted config uses `configMapGenerator` plus a
   `resources/` directory (see recyclarr). A structured config file that
   mixes sensitive and non-sensitive content and cannot cleanly split into
   ExternalSecret fields may be committed as a directly SOPS-encrypted Secret
   instead (no current app does; resolute did, see Git history) — that is
   an exception, not
   the default. Ordinary credentials always go through
   1Password/ExternalSecret; never encrypt them directly into Git.
7. **Dependencies**: almost never — `dependsOn` follows the doctrine in
   `docs/guides/cluster-model.md`; the default is none.

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

- `components` (kopiur): only with a Kopiur PVC.
- `postBuild.substitute.APP` is required by the Kopiur component; add
  `PVC_CAPACITY` when the component default (5Gi) is wrong.
- `postBuild.substituteFrom: cluster-secrets`: needed for `${SECRET_DOMAIN}`
  and other substituted values, and it only works in namespaces whose
  `kustomization.yaml` includes the SOPS component (`../../components/sops`) —
  check before copying, because without the component the referenced Secret
  does not exist there and reconciliation fails. Drop the block if the app
  substitutes nothing.
- `targetNamespace` matches the namespace directory.

### app/kustomization.yaml

Copy atuin's. Resources are listed alphabetically. With config files, copy
recyclarr's `configMapGenerator` block (name `<app>-configmap`, one entry per
`resources/` file, `disableNameSuffixHash: true`).

### app/ocirepository.yaml

Copy atuin's. The chart is `oci://ghcr.io/bjw-s-labs/helm/app-template`; use
the same chart tag as nearby apps (Renovate bumps it). Keep atuin's `verify`
block verbatim — it pins the app-template signing identity. For any other
chart, derive the identity per ADR-0003 (or omit `verify` and record the
source as unverified); never copy another chart's identity.

### app/helmrelease.yaml

Copy atuin's and adapt. Invariants to keep:

- Schema comment pointing at the app-template helmrelease schema.
- `spec.values` order: `controllers`, `defaultPodOptions`, `service`, `route`,
  `configMaps`, `persistence` (see
  `docs/guides/yaml-ordering.md`).
- `defaultPodOptions.securityContext` for Kopiur-backed apps only:
  `runAsNonRoot: true`, `runAsUser: 1032`, `runAsGroup: 100`, `fsGroup: 100`,
  `fsGroupChangePolicy: OnRootMismatch` — the identity the Kopiur movers and
  the NAS convention expect (`docs/operations/storage-and-backups.md`). Apps
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
  config mounts as `type: secret` (see resolute in Git history).
- Secrets arrive via `envFrom` from `"{{ .Release.Name }}-secret"`, with
  `reloader.stakater.com/auto: "true"` on the controller.
- SQLite or other single-writer apps: `replicas: 1` with
  `strategy: Recreate`, and a comment saying not to scale.

### app/externalsecret.yaml

Copy autobrr's `externalsecret.yaml`: `ClusterSecretStore`
`onepassword-connect`, a `target.template.data` map from 1Password fields to
the env names the app expects, and `dataFrom.extract` per 1Password item.

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
