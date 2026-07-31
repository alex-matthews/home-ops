# Storage and Backups

Current storage and backup posture. Update it when backup topology changes,
after restore drills, or when the operational rules below stop holding.

## Current Posture

Persistent application data lives on Rook-Ceph `ceph-block` PVCs. Some
media-adjacent workloads also mount Synology NAS storage over NFS at runtime.

Kopiur is the only backup system. It provides both the snapshot path and the
passive `Restore` population path for every protected application PVC:

- hourly snapshots to a local Garage S3 repository on the NAS;
- daily snapshots to an independent Cloudflare R2 repository, with its own
  credentials, encryption password, cadence and retention;
- a passive `Restore` per app, which populates the PVC on creation and makes a
  clean-cluster rebuild declarative.

The local path deliberately uses Garage S3 rather than inline NFS so backup
and restore IO does not pass through the NFS daemon — restore-scale reads on
NFS previously made the daemon unresponsive and tripped the zeroscaler
guardrail. Do not route that traffic back through NFS.

The two repositories are independent by design ([ADR-0002](../adr/0002-kopiur-backup-storage-shape.md)):
no replication between them, so local repository damage cannot propagate
off-site.

VolSync was retired on 2026-07-25 after the fleet cutover, post-cutover
incrementals, and fleet-wide database integrity verification all passed. Its
Restic repositories are not deleted; recovering from them means restoring the
manifests from Git history.

## UID/GID And Mover Permissions

Linux storage permissions are numeric. Names such as `docker`, `node`, or
`admin` are only labels on the system that defines them. Keep three identities
separate:

- the app data owner: the UID/GID that owns files in the source PVC;
- the mover identity: the UID/GID used by the backup or restore job;
- the NAS/export identity: the UID/GID or server-side mapping used by NFS paths
  when the app touches Synology storage.

The default for protected apps is `1032:100` for both the app pod and the
Kopiur movers, matching the NAS-side `docker` convention. It is this cluster's
convention, not a Kopiur requirement, and it is set explicitly on every policy
and `Restore` rather than inherited from a live pod — explicit identity is what
makes restores work with no workload running, including on a rebuilt cluster.

For NAS/NFS paths, do not rely on `fsGroup` to fix server-side ownership. NFS
exports may apply root squash or server-side UID/GID mapping.

Before adding an app to the protected set or changing its mover identity,
verify the actual numeric ownership and file modes on the PVC. If an app's
runtime identity changes, migrate PVC ownership in the same window and prove
the app can read and write afterwards.

Plex retains historical `1000:100` entries alongside newer `1032:100` ones.
They are group-writable, Plex runs as `1032:100`, and a Kopiur restore
normalises ownership naturally — do not churn the source PVC to fix them.

## Protected Application Inventory

Scope: every app whose Kustomization includes the `kopiur` component. That is
the rule to re-derive this table from, not the `default` namespace membership —
stateless apps in `default` are deliberately outside it. Every row therefore has
both local and remote protection, so the table records only what varies.
Separately declared cache PVCs are runtime-only and are not backup sources.

| App           | App PVC | Runtime NAS | Zeroscaler | Other state or constraint          |
| ------------- | ------- | ----------- | ---------- | ---------------------------------- |
| `agregarr`    | 5Gi     | no          | no         | —                                  |
| `atuin`       | 5Gi     | no          | no         | —                                  |
| `autobrr`     | 5Gi     | no          | no         | —                                  |
| `bazarr`      | 5Gi     | yes         | yes        | —                                  |
| `brrpolice`   | 5Gi     | no          | no         | —                                  |
| `maintainerr` | 5Gi     | no          | no         | —                                  |
| `plex`        | 50Gi    | yes         | yes        | `plex-cache` 75Gi runtime PVC      |
| `prowlarr`    | 5Gi     | no          | no         | —                                  |
| `qbittorrent` | 5Gi     | yes         | yes        | —                                  |
| `qui`         | 5Gi     | yes         | yes        | —                                  |
| `radarr`      | 5Gi     | yes         | yes        | `radarr-cache` 10Gi runtime PVC    |
| `radarr-se`   | 5Gi     | yes         | yes        | `radarr-se-cache` 10Gi runtime PVC |
| `recyclarr`   | 5Gi     | no          | no         | CronJob                            |
| `resolute`    | 5Gi     | no          | no         | Single-writer SQLite API           |
| `sabnzbd`     | 5Gi     | yes         | yes        | —                                  |
| `seerr`       | 5Gi     | no          | no         | `seerr-cache` 15Gi runtime PVC     |
| `sonarr`      | 5Gi     | yes         | yes        | `sonarr-cache` 10Gi runtime PVC    |
| `tautulli`    | 5Gi     | no          | no         | `tautulli-cache` 15Gi runtime PVC  |
| `thelounge`   | 5Gi     | no          | no         | —                                  |

Zeroscaler protects apps that need NAS access at runtime. It does not protect a
backup mover by itself.

## Intentional Non-Coverage

Observability PVCs — Prometheus, Alertmanager, Grafana, the Gatus sidecar,
Victoria Logs — are deliberately outside the backup set. Losing them loses
telemetry history or non-declarative UI state, not the Git source of truth.

Hermes and the AI workbench are intentionally stateless; the Hermes home
directory is an `emptyDir`. Do not add persistence or backup coverage unless
the workbench design changes.

`chaski` runs in `default` with no PVC and no Kopiur component. It is stateless
by design, so its absence from the table above is deliberate rather than a gap.

## Components

`kubernetes/components/kopiur` composes three concerns, and every protected app
includes the root:

- `local` — `SnapshotPolicy` + `SnapshotSchedule` against the Garage
  repository, hourly on a hashed minute, `keepLatest 3 / hourly 24 / daily 7 /
weekly 4`;
- `remote` — the same against R2, daily in the `H 3` window, `daily 7 /
weekly 4 / monthly 3`;
- `restore` — a passive `Restore` (`source.fromPolicy`, `target.populator`,
  `onMissingSnapshot: Fail`) plus the application PVC whose `dataSourceRef`
  consumes it.

`kubernetes/components/kopiur/secrets` holds the repository credentials and is
included at namespace level in both `default` and `kopiur-system`, not per app.

Fail-closed population is deliberate: a missing or mismatched snapshot must
block the app rather than silently create an empty volume. When population
starts, the mover resolves offset 0 against the repository and does not
re-resolve for that `Restore`; recreating the `Restore` without status — as a
clean cluster bootstrap does — selects the repository's latest snapshot again.

## PVC Lifecycle Policy

Protected app PVCs are managed by the same Flux Kustomization as their app and
are therefore prunable when an app is deliberately removed.

Application PVC capacity is provider-neutral: `PVC_CAPACITY` defaults to 5Gi,
Plex keeps 50Gi, and separately declared runtime caches keep their own sizes.
Kopiur's local and remote mover caches both use `KOPIUR_CACHE_CAPACITY`,
defaulting to 5Gi, independent of application PVC sizing.

Treat app renames, PVC renames, component rewiring, and `APP` substitution
changes as storage migrations rather than refactors. Before merging one, verify
a recent local and remote snapshot and make any destructive PVC deletion an
explicit operator action — see the `maintenance-window` skill.

`ceph-block` is `reclaimPolicy: Delete`. Deleting a PVC destroys the underlying
volume; recovery is from the repositories only.

## Kopia Maintenance

Maintenance is required operational work, not cleanup polish. Quick maintenance
keeps repository metadata healthy; full maintenance reclaims storage after
snapshot expiration.

Both repositories run quick maintenance 6-hourly and full maintenance daily,
staggered so the local and remote full runs do not overlap each other or the
remote snapshot window. Watch duration, failure count, repository size, and
restore-test outcomes. Do not disable maintenance.

## Cluster-Scoped Resources

Kopiur owns one resource outside its namespace. From chart 0.9.1 the operator
ships a default-on `FlowSchema`, `kopiur-leader-election`, at
`matchingPrecedence: 200`. It places the operator ServiceAccount's
`coordination.k8s.io/leases` get/create/update calls in `kopiur-system` into
the built-in guaranteed API Priority and Fairness lane, so a busy API server
cannot starve leader-election renewals. It grants no new permissions — it only
re-prioritises calls the ServiceAccount already made. Disable with
`leaderElection.flowSchema.enabled: false` if it ever conflicts with another
FlowSchema.

The same release added the `KopiurLeaderElectionFlapping` and
`KopiurLeaderRenewSlow` alerts, and dropped the upstream lease renew period
from 5s to 2s. The `leaderElection.timings.*` values render only when set;
they are not set here, so the upstream defaults apply.

## Known Quirks

Observed on 0.7.5 through 0.9.1; re-test on upgrades and file upstream if still
present when one next bites.

- A `Repository` whose repository-level Job has exhausted `backoffLimit` goes
  `Stalled` and is not retried when the spec changes — the exhausted Job blocks
  it. Recovery: fix the cause, then delete that Job in the repository's
  namespace. The Job is `<repo>-discovery` from 0.8.1 onward and
  `<repo>-bootstrap` before that; upgrading reaps the legacy Job once per
  repository. The kopia username sentinel is deliberately not renamed, so
  snapshots taken on 0.8.0 stay resolvable.
- Repository-level movers take their identity from
  `spec.moverDefaults.securityContext`, not from any `SnapshotPolicy`. Left
  unset they run as UID 65532.
- `Maintenance` CR status is unreliable even though maintenance runs correctly:
  `nextScheduledAt` is never written, `lastHandledAt` is skipped for successful
  runs, and `consecutiveFailures` has no writer. Verify maintenance from mover
  Job history and metrics, not CR status. Still present as of 0.9.0.
- `Restore` CR status carries no stats. Verify a restore from the target PVC's
  contents, not from the CR.
- Restore movers emit a non-fatal warning when they cannot read the parent
  `Restore` status with their narrow service-account permissions. Restores
  still succeed; do not widen mover RBAC locally.
- Persistent mover-cache PVCs are create-only. Changing `mover.cache.capacity`
  affects new claims only; expand an existing cache through the PVC and expect
  `FileSystemResizePending` until the next mover mount completes the resize. A
  Ready `SnapshotPolicy` does not prove its cache matches configured capacity.
- Deleting a `SnapshotPolicy`/`SnapshotSchedule`, including via Flux prune,
  cascades only to `Snapshot` CRs (`onPolicyDelete`/`onScheduleDelete`, default
  `Retain`). Repository-side deletions route through the mass-deletion circuit
  breaker (`deletionProtection.threshold`, default 10); deleting more than ten
  snapshots at once holds with `DeletionHeld=True` until the repository is
  annotated `kopiur.home-operations.com/allow-mass-deletion=<RFC3339>`.
- From 0.8.1 the chart's `ServiceMonitor` sets `honorLabels: true`, so
  `kopiur_*` series carry the CR's namespace. Write queries against
  `namespace`, not `exported_namespace`.
- Suspending an app's Flux Kustomization does not stop Kopiur acting on live
  CRs, and per-object holds do not survive the next successful apply. See the
  `maintenance-window` skill before any window that depends on one.

## Verifying A Restore

Check restored data against a recorded baseline rather than "the app started".
File counts and ownership from the source snapshot's stats are the cheapest
useful comparison.

For database integrity, work from an isolated copy — CSI-snapshot the PVC,
clone it, and check the clone. Checking a live database an app is writing can
report false corruption, and a read-only mount blocks the `-shm` file a WAL
database needs. Mount the throwaway clone writable. Python's standard library
`sqlite3` avoids needing a package install. Plex ships its own SQLite at
`/usr/lib/plexmediaserver/Plex SQLite`; stock clients fail on its collation.

An unreadable database is not a passing result — change the method until it
reads.

## Validation Commands

Read-only checks:

```sh
kubectl get clusterrepository,snapshotpolicy,snapshotschedule,snapshot,restores.kopiur.home-operations.com -A
kubectl -n kopiur-system get maintenance,job
kubectl get persistentvolumeclaim -A
kubectl -n default get hpa
kubectl -n observability get probe nfs -o yaml
```

Render checks for manifest changes:

```sh
kubectl kustomize kubernetes/apps/default
mise exec -- flate test all -p ./kubernetes/flux/cluster --allow-missing-secrets
```

## References

- [ADR-0002: Kopiur backup storage shape](../adr/0002-kopiur-backup-storage-shape.md)
- [Kopiur](https://github.com/home-operations/kopiur)
