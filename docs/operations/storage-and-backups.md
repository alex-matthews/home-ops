# Storage and Backups

This document captures the current storage and backup posture and the selected
direction for a future Kopia migration. It is intentionally short-lived and
practical: update it when backup topology changes, after restore drills, or when
the migration criteria change.

## Current Posture

Persistent application data primarily lives on Rook-Ceph `ceph-block` PVCs.
Selected media-adjacent workloads also mount Synology NAS storage over NFS at
runtime. VolSync currently protects app PVCs with Restic.

The shared VolSync component creates three things for each participating app:

- A local Restic `ReplicationSource` scheduled hourly.
- A local Restic `ReplicationDestination` used by restore workflows.
- A remote Restic `ReplicationSource` scheduled daily against the R2 secret
  template.

The remote target is intentional. Any future Kopia design must preserve both a
local target for fast restores and a remote object-storage target for disaster
recovery.

## UID/GID And Mover Permissions

The current default for VolSync-backed apps is to run the app and the VolSync
Restic movers as UID `1032` and GID `100`. This matches the NAS-side `docker`
user/group convention and keeps single-app PVC backup and restore paths
unprivileged in principle:

- app pods should usually set `runAsUser: 1032`, `runAsGroup: 100`, and
  `fsGroup: 100`;
- the shared VolSync component defaults `VOLSYNC_PUID` to `1032` and
  `VOLSYNC_PGID` to `100`;
- use per-app `VOLSYNC_PUID` or `VOLSYNC_PGID` only when an app genuinely must
  write its PVC as a different identity.

The `default` namespace currently allows VolSync privileged movers. Treat that
as a compatibility escape hatch, not the normal permission model. For a
single-app PVC, prefer matching the mover identity to the workload identity. Use
privileged movers only for mixed ownership, root-owned data, or restore cases
that must preserve arbitrary original ownership.

For NAS/NFS paths, do not rely on `fsGroup` to fix server-side ownership. NFS
exports may apply root squash or server-side UID/GID mapping. Match the UID/GID
the NAS expects, or use a deliberate shared group/server-side remap.

Before migrating an app to Kopiur, verify the actual numeric ownership and file
modes on the PVC. Kopiur movers are separate pods too; configure them to inherit
or explicitly match the workload identity before trusting a snapshot.

Known exceptions: `tautulli` and `thelounge` currently run as UID/GID
`1000:1000` while the shared VolSync movers keep the default `1032:100`
identity. Leave that alone for now and rely on privileged VolSync movers, but do
not migrate either app to Kopiur without explicit mover identity handling.

## Backup Inventory

This inventory is derived from the currently included resources in
`kubernetes/apps/default/kustomization.yaml`.

| App           | VolSync local | VolSync remote | Runtime NAS | Zeroscaler | Notes                                                         |
| ------------- | ------------- | -------------- | ----------- | ---------- | ------------------------------------------------------------- |
| `agregarr`    | yes           | yes            | no          | no         | Default VolSync capacity.                                     |
| `atuin`       | yes           | yes            | no          | no         | First Kopiur pilot candidate; 1Gi VolSync capacity.           |
| `autobrr`     | yes           | yes            | no          | no         | Default VolSync capacity.                                     |
| `bazarr`      | yes           | yes            | yes         | yes        | NAS availability controls app scale.                          |
| `brrpolice`   | yes           | yes            | no          | no         | Default VolSync capacity.                                     |
| `plex`        | yes           | yes            | yes         | yes        | Custom VolSync capacity and cache; separate `plex-cache` PVC. |
| `prowlarr`    | yes           | yes            | no          | no         | Default VolSync capacity.                                     |
| `qbittorrent` | yes           | yes            | yes         | yes        | NAS availability controls app scale.                          |
| `qui`         | yes           | yes            | yes         | yes        | NAS availability controls app scale.                          |
| `radarr`      | yes           | yes            | yes         | yes        | Separate `radarr-cache` PVC.                                  |
| `radarr-se`   | yes           | yes            | yes         | yes        | Separate `radarr-se-cache` PVC.                               |
| `recyclarr`   | yes           | yes            | no          | no         | CronJob workload; default VolSync capacity.                   |
| `sabnzbd`     | yes           | yes            | yes         | yes        | NAS availability controls app scale.                          |
| `seerr`       | yes           | yes            | no          | no         | Separate `seerr-cache` PVC.                                   |
| `sonarr`      | yes           | yes            | yes         | yes        | Separate `sonarr-cache` PVC.                                  |
| `tautulli`    | yes           | yes            | no          | no         | Runs as `1000:1000`; separate `tautulli-cache` PVC.           |
| `thelounge`   | yes           | yes            | no          | no         | Runs as `1000:1000`; handle explicitly before Kopiur.         |

Zeroscaler protects apps that need NAS access at runtime. It does not protect a
backup mover job by itself. If a future local Kopia target uses NFS only inside
backup jobs, protect that path with backup scheduling, alerts, restore tests, and
maintenance monitoring rather than by scaling unrelated app workloads.

A more conservative future policy is possible: apply zeroscaler to every
VolSync/Kopiur-backed Deployment, even if the app does not currently mount NAS
storage at runtime. If that policy is adopted, document it as a deliberate
availability posture and handle non-Deployment workloads separately.

## Migration Requirements

A replacement for the current Restic posture must satisfy these requirements:

1. Keep a local target for low-latency restores.
2. Keep a remote object-storage target, currently expected to be Cloudflare R2 or
   an S3-compatible equivalent.
3. Provide explicit, observable Kopia maintenance for every repository.
4. Support restore testing into a temporary PVC before any production restore
   workflow is trusted.
5. Keep Restic in place until the replacement has completed successful backup,
   maintenance, and restore tests.
6. Avoid broad app migrations until the pilot app has proven backup runtime,
   maintenance runtime, and restore behavior.

## Kopia Maintenance

Kopia maintenance is required operational work, not cleanup polish. Quick
maintenance keeps repository metadata healthy. Full maintenance is heavier and
is what reclaims storage after snapshot expiration.

For this cluster, assume NAS-backed full maintenance may be slow or IO-heavy.
Start with conservative schedules and measure before expanding:

- Run backups and full maintenance outside busy media windows.
- Use jitter or app grouping so many repositories do not maintain at once.
- Set resource requests, limits, retry policy, and active deadlines on mover jobs
  once the chosen tool supports them.
- Watch maintenance duration, failure count, repository size, and restore test
  outcomes.
- Treat remote object-store maintenance separately from local NAS maintenance
  because it has different latency, cost, and failure modes.

Do not disable maintenance unless another process is reliably running it and is
observable from the cluster.

## Migration Decision

VolSync Restic remains the working backup system. Do not migrate to
VolSync-Kopia as an intermediate step.

The selected Kopia migration path is Kopiur, after it has proved itself enough
for this cluster:

1. Keep VolSync Restic as the production backup system.
2. Test-deploy Kopiur without disturbing existing Restic backups.
3. Prove a local backup and restore on one low-risk PVC.
4. Prove a remote object-storage target for the same pilot.
5. Verify Kopiur maintenance behavior, status, alerts, and failure modes.
6. Wait for the project to mature enough, with peer testing considered useful
   evidence but not a substitute for local restore tests.
7. Expand only after local and remote maintenance and restore behavior are
   acceptable.

Kopiur adoption should follow the deploy-or-restore model used by current peer
testing: install the operator and repository first, add a reusable app component
for SnapshotPolicy, SnapshotSchedule, PVC, and Restore resources, then migrate
apps one at a time. A bound PVC's `dataSourceRef` is immutable, so app migration
is a deliberate cutover rather than an in-place mutation.

### Why Not VolSync-Kopia

VolSync-Kopia is no longer the planned migration path. It would be an
intermediate migration from VolSync Restic to a Kopia mover inside the VolSync
model, followed by a later migration to Kopiur if Kopiur becomes the preferred
long-term tool.

That double migration is not worth taking unless Kopiur stalls or proves
unsuitable. The cluster should keep the known-good Restic posture while Kopiur
matures, rather than adopting a transitional backup implementation.

### Why Kopiur

Kopiur is the selected candidate because it is Kopia-native rather than a
retrofit into VolSync's Restic-shaped model. Its design direction better matches
the desired end state: repository resources, separate backup configs and
schedules, restore resources, multiple backends including S3-compatible object
storage, and first-class maintenance.

It is still not the primary backup system. Do not make it production until the
cluster has local and remote pilot backups, maintenance runs, restore tests, and
acceptable operational behavior. Peer testing in other home-ops clusters is a
positive signal, but this cluster still needs its own restore evidence.

## Suggested Pilot

Use Atuin as the first Kopiur pilot. Track the deployment in
[Deploy atuin](https://github.com/alex-matthews/home-ops/issues/1266).

Atuin is a good pilot because it is useful, small, and lower-risk than the
media-adjacent workloads. Do not add Kopiur resources for it until the Atuin app
and VolSync-protected PVC are healthy and the client dotfiles integration is
understood.

Pilot success means:

- The existing Restic backup remains untouched.
- A Kopiur-managed Kopia backup completes to the selected local target.
- Kopiur maintenance completes and reports useful status.
- A restore into a temporary PVC completes.
- The same pattern works against the remote object-storage target.
- Rollback is simply deleting the pilot Kopia resources.

App cutover should not proceed until a Kopiur snapshot for that app has
succeeded with non-zero file content. The expected cutover shape is:

1. Scale the app down.
2. Delete the old app PVC deliberately.
3. Let Flux recreate the PVC with the Kopiur `Restore` data source.
4. Confirm the restored PVC contents.
5. Scale the app back up.

## Validation Commands

Useful read-only checks:

```sh
kubectl get replicationsource,replicationdestination -A
kubectl get persistentvolumeclaim -A
kubectl -n default get hpa
kubectl -n observability get probe nfs -o yaml
```

Current Restic snapshot and restore helpers:

```sh
just volsync list-previous default <app>
just volsync restore default <app> 0
```

Render checks for future manifest changes:

```sh
kubectl kustomize kubernetes/apps/default
flate test all -p ./kubernetes/flux/cluster --allow-missing-secrets
```

## References

- [Kopiur](https://github.com/home-operations/kopiur)
- [onedr0p/home-ops#11012: deploy Kopiur](https://github.com/onedr0p/home-ops/pull/11012)
