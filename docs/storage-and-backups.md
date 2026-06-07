# Storage and Backups

This document captures the current storage and backup posture and the decision
criteria for a future Kopia migration. It is intentionally short-lived and
practical: update it when backup topology changes, after restore drills, or when
selecting a new backup operator.

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

## Backup Inventory

This inventory is derived from the current `default` namespace app tree.

| App             | VolSync local | VolSync remote | Runtime NAS | Zeroscaler | Notes                                                         |
| --------------- | ------------- | -------------- | ----------- | ---------- | ------------------------------------------------------------- |
| `agregarr`      | yes           | yes            | no          | no         | Default VolSync capacity.                                     |
| `autobrr`       | yes           | yes            | no          | no         | Default VolSync capacity.                                     |
| `bazarr`        | yes           | yes            | yes         | yes        | NAS availability controls app scale.                          |
| `brrpolice`     | yes           | yes            | no          | no         | Default VolSync capacity.                                     |
| `costanza`      | yes           | yes            | no          | no         | Small VolSync capacity; good pilot candidate.                 |
| `plex`          | yes           | yes            | yes         | yes        | Custom VolSync capacity and cache; separate `plex-cache` PVC. |
| `prowlarr`      | yes           | yes            | no          | no         | Default VolSync capacity.                                     |
| `qbittorrent`   | yes           | yes            | yes         | yes        | NAS availability controls app scale.                          |
| `qui`           | yes           | yes            | yes         | yes        | NAS availability controls app scale.                          |
| `radarr`        | yes           | yes            | yes         | yes        | Separate `radarr-cache` PVC.                                  |
| `radarr-se`     | yes           | yes            | yes         | yes        | Separate `radarr-se-cache` PVC.                               |
| `recyclarr`     | yes           | yes            | no          | no         | Default VolSync capacity.                                     |
| `sabnzbd`       | yes           | yes            | yes         | yes        | NAS availability controls app scale.                          |
| `seerr`         | yes           | yes            | no          | no         | Separate `seerr-cache` PVC.                                   |
| `sonarr`        | yes           | yes            | yes         | yes        | Separate `sonarr-cache` PVC.                                  |
| `tautulli`      | yes           | yes            | no          | no         | Separate `tautulli-cache` PVC.                                |
| `thelounge`     | yes           | yes            | no          | no         | Default VolSync capacity.                                     |

Zeroscaler protects apps that need NAS access at runtime. It does not protect a
backup mover job by itself. If a future local Kopia target uses NFS only inside
backup jobs, protect that path with backup scheduling, alerts, restore tests, and
maintenance monitoring rather than by scaling unrelated app workloads.

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

## Tooling Decision

The decision is not yet Restic versus Kopia in one step. The safer path is:

1. Keep VolSync Restic as the working backup system.
2. Pilot Kopia in parallel on one low-risk PVC.
3. Restore the pilot backup into a temporary PVC.
4. Add a remote target for the same pilot.
5. Expand only after maintenance and restore behavior are proven.

### VolSync-Kopia

Prefer this path if the goal is a nearer-term Kopia migration that stays close
to the existing VolSync model. Before choosing it, verify remote target support,
maintenance behavior, restore ergonomics, and how much it diverges from the
current Restic restore helpers.

### Kopiur

Prefer this path as an evaluation of the emerging Kopia-native operator model.
It has promising design traits: repository resources, separate backup configs
and schedules, restore resources, multiple backends including S3-compatible
object storage, and first-class maintenance.

It is also alpha software. Do not make it the primary backup system until the
cluster has local and remote pilot backups, maintenance runs, and restore tests
with acceptable behavior.

## Suggested Pilot

Use a low-risk app with a small PVC first. `costanza` is a reasonable candidate
because it already uses VolSync and has a small custom capacity. Pick a
different app if operational importance makes it a poor test target.

Pilot success means:

- The existing Restic backup remains untouched.
- A Kopia backup completes to the selected local target.
- Kopia maintenance completes and reports useful status.
- A restore into a temporary PVC completes.
- The same pattern works against the remote object-storage target.
- Rollback is simply deleting the pilot Kopia resources.

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
just volsync list-previous default costanza
just volsync restore default costanza 0
```

Render checks for future manifest changes:

```sh
kubectl kustomize kubernetes/apps/default
flate test all --allow-missing-secrets
```
