---
name: add-app
description: Scaffolds a new Flux-managed application under kubernetes/apps/, covering chart selection, manifests, registration and validation. Use when deploying a new app or service to the cluster.
---

# Add a New Application

Scaffolds `kubernetes/apps/<namespace>/<app>/` with a Flux Kustomization and a
HelmRelease (chart chosen in Step 0). Use the source apps below as patterns,
checking their current configuration and suitability before copying:

| Reference app                       | Shows                                                                             |
| ----------------------------------- | --------------------------------------------------------------------------------- |
| `kubernetes/apps/default/atuin`     | Small app: internal route, Kopiur-backed PVC, no secrets                          |
| `kubernetes/apps/default/recyclarr` | Config files via `configMapGenerator` + `resources/`                              |
| `kubernetes/apps/default/plex`      | Public route on `envoy-external`, Gatus endpoint annotation, LoadBalancer service |

Read the [app pattern](references/app-pattern.md) first: layout, wiring, the
`ks.yaml` and app-template HelmRelease shapes, substitution, persistent state
and YAML ordering.

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
   default), or public (`envoy-external`; public routes follow the
   [public-surface policy](../../../docs/policy/public-surfaces.md)).
4. **Persistence**: choose backup posture from the app's value and recovery
   requirements, not from the presence of a PVC. Read the
   [volume prerequisites](../restore-data/references/app-volumes.md) before
   selecting recovery wiring, including ownership and the missing-snapshot stop.
   Protected application state
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
   instead. This is a storage format exception, not permission for an agent
   to create or edit credential material. Ordinary credentials always go through
   1Password/ExternalSecret; never encrypt them directly into Git.
7. **Database**: for PostgreSQL, follow [policy and admission](../../../docs/policy/decisions.md#postgresql)
   before adding a consumer. Use [the existing consumer](../../../kubernetes/apps/database/postgres/app/litellm.yaml)
   as the DatabaseRole/Database and reload-labelled Secret pattern; connect
   through `postgres-rw`. Declare required extensions on the Database.
8. **Dependencies**: `dependsOn` follows the
   [reconciliation ordering rule](../../../docs/policy/decisions.md#reconciliation-ordering);
   the default is none.

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

Copy atuin's `ks.yaml`. Keep the key order and drop what does not apply, as
the [app pattern](references/app-pattern.md#flux-kustomization) lists.

### app/kustomization.yaml

Copy atuin's. Resources are listed alphabetically. With config files, copy
recyclarr's `configMapGenerator` block (name `<app>-configmap`, one entry per
`resources/` file, `disableNameSuffixHash: true`).

### app/ocirepository.yaml

Copy atuin's. The chart is `oci://ghcr.io/bjw-s-labs/helm/app-template`; use
the same chart tag as nearby apps (Renovate bumps it). Keep atuin's `verify`
block verbatim — it pins the app-template signing identity. For any other
chart, first see what the registry shows:

```bash
.github/scripts/chart-signing-check.sh kubernetes/apps/<namespace>/<app>/app/ocirepository.yaml
```

Then inspect any discovered material and either derive the identity under
[chart trust](../../../docs/policy/decisions.md#chart-trust) and add a `verify` block, or record the exclusion reason in
`home-ops/chart-verify-exclusion-reason`: `unsigned`, `keyed-unpinned`,
`verifier-gap` or `unverifiable`. Discovery does not classify or verify the
material. Non-unsigned reasons require manual investigation and opt the source
out of ongoing discovery. Coverage rejects missing or conflicting declarations.
Never copy another chart's identity; see [chart trust](../../../docs/policy/decisions.md#chart-trust).

### app/helmrelease.yaml

Copy atuin's and adapt. Keep the
[invariants](references/app-pattern.md#app-template-helmrelease).

### app/externalsecret.yaml

Copy sonarr's `externalsecret.yaml`: `ClusterSecretStore`
`onepassword-connect`, a `target.template.data` map from 1Password fields to
the env names the app expects, and `dataFrom.extract` per 1Password item.

## Step 3: Register the app

Add `./<app>/ks.yaml` to `kubernetes/apps/<namespace>/kustomization.yaml`,
keeping the list alphabetical.

## Step 4: Validate

Use [validation](../../../CONTRIBUTING.md#validate-locally) for the matching app,
image, chart-trust and formatting checks. Inspect the new app and any shared
component changes in the rendered output; account for missing-input warnings
and every image change. Local rendering does not prove live reconciliation
or restore success. Present the complete diff and actual check results;
commit, push and PR creation require the owner's approval.
