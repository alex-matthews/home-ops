# Storage and Backups

This document captures the current storage and backup posture and the phased
Kopiur rollout. It is intentionally practical: update it when backup topology
changes, after restore drills, or when the migration criteria change.

## Current Posture

Persistent application data primarily lives on Rook-Ceph `ceph-block` PVCs.
Selected media-adjacent workloads also mount Synology NAS storage over NFS at
runtime. Kopiur supplies the passive Restore population path for protected
application PVCs. VolSync continues to protect them with Restic backups during
the rollback window.

All 19 protected application PVCs have hourly Kopiur snapshots to the local
Garage S3 repository and daily snapshots to the independent R2 repository.
VolSync remains enabled for local and remote backups until the clean-cluster
rebuild and application verification pass.

The shared VolSync component creates two things for each participating app:

- A local Restic `ReplicationSource` scheduled hourly.
- A remote Restic `ReplicationSource` scheduled daily against the R2 secret
  template.

The VolSync local and remote restore helpers remain in Git for rollback and
disaster recovery, but they are not composed into the live cutover state.

The independent remote target is intentional. The rollout preserves both a
local target for fast restores and a remote object-storage target for disaster
recovery.

## UID/GID And Mover Permissions

Linux storage permissions are numeric. Names such as `docker`, `node`, or
`admin` are only labels on the system that defines them. For backups and
restores, keep three identities separate:

- the app data owner: the UID/GID that owns files in the source PVC;
- the mover identity: the UID/GID used by the backup or restore job;
- the NAS/export identity: the UID/GID or server-side mapping used by NFS paths
  when the app or backup repository touches Synology storage.

The current default for protected apps is `1032:100` for the app pod, Kopiur
movers, and VolSync Restic movers. This matches the NAS-side `docker` convention
and keeps most single-app PVC backup and restore paths unprivileged in
principle. It is this cluster's convention, not a Kopiur requirement.

The `default` namespace currently allows VolSync privileged movers. Treat that
as a compatibility escape hatch, not the normal permission model. For a
single-app PVC, prefer matching the mover identity to the workload identity:
backup movers must be able to read the source PVC, and restore movers should
write files with ownership the app can use afterward.

For NAS/NFS paths, do not rely on `fsGroup` to fix server-side ownership. NFS
exports may apply root squash or server-side UID/GID mapping. Match the UID/GID
the NAS expects, or use a deliberate shared group/server-side remap. If a future
Kopia repository uses NFS, repository write permissions are a separate problem
from source PVC read permissions.

Before migrating any app to Kopiur, verify the actual numeric ownership and file
modes on the PVC. Kopiur movers are separate pods too; every app needs an
explicit mover identity decision before trusting a snapshot. For apps already
aligned to `1032:100`, that can be inheritance or an explicit matching context.

Historical `1000:1000` app exceptions should not be reintroduced as manifest-only
changes. If an app's runtime identity changes, migrate the PVC ownership in the
same maintenance window and prove the app can read and write its data afterward.

Plex retains historical `1000:100` entries alongside newer `1032:100` entries.
The legacy entries are group-writable, Plex runs as `1032:100`, and the remote
restore drill normalised the restored application PVC to `1032:100`. Do not
churn the source PVC with a pre-cutover ownership rewrite; the Kopiur restore
produces the desired ownership naturally.

## Backup Inventory

This inventory is derived from the currently included resources in
`kubernetes/apps/default/kustomization.yaml`.

| App           | VolSync local | VolSync remote | Runtime NAS | Zeroscaler | Notes                                                      |
| ------------- | ------------- | -------------- | ----------- | ---------- | ---------------------------------------------------------- |
| `agregarr`    | yes           | yes            | no          | no         | Default application capacity.                              |
| `atuin`       | yes           | yes            | no          | no         | Default application capacity.                              |
| `autobrr`     | yes           | yes            | no          | no         | Default application capacity.                              |
| `bazarr`      | yes           | yes            | yes         | yes        | Kopiur local + remote acceptance; VolSync remains enabled. |
| `brrpolice`   | yes           | yes            | no          | no         | Default application capacity.                              |
| `maintainerr` | yes           | yes            | no          | no         | Default application capacity.                              |
| `plex`        | yes           | yes            | yes         | yes        | 50Gi app; separate runtime and VolSync caches.             |
| `prowlarr`    | yes           | yes            | no          | no         | Default application capacity.                              |
| `qbittorrent` | yes           | yes            | yes         | yes        | NAS availability controls app scale.                       |
| `qui`         | yes           | yes            | yes         | yes        | NAS availability controls app scale.                       |
| `radarr`      | yes           | yes            | yes         | yes        | Separate `radarr-cache` PVC.                               |
| `radarr-se`   | yes           | yes            | yes         | yes        | Separate `radarr-se-cache` PVC.                            |
| `recyclarr`   | yes           | yes            | no          | no         | CronJob workload; default application capacity.            |
| `resolute`    | yes           | yes            | no          | no         | Default application capacity; single-writer SQLite API.    |
| `sabnzbd`     | yes           | yes            | yes         | yes        | NAS availability controls app scale.                       |
| `seerr`       | yes           | yes            | no          | no         | Separate `seerr-cache` PVC.                                |
| `sonarr`      | yes           | yes            | yes         | yes        | Separate `sonarr-cache` PVC.                               |
| `tautulli`    | yes           | yes            | no          | no         | Separate `tautulli-cache` PVC.                             |
| `thelounge`   | yes           | yes            | no          | no         | Local restore drill passed.                                |

Zeroscaler protects apps that need NAS access at runtime. It does not protect a
backup mover job by itself. Kopiur's production local path deliberately uses
Garage S3 rather than inline NFS so backup and restore IO does not pass through
the NFS daemon. Do not route that traffic back through NFS.

A more conservative future policy is possible: apply zeroscaler to every
VolSync/Kopiur-backed Deployment, even if the app does not currently mount NAS
storage at runtime. If that policy is adopted, document it as a deliberate
availability posture and handle non-Deployment workloads separately.

## Intentional Non-Coverage

The inventory above is scoped to the `default` namespace application PVCs.
Observability PVCs such as Prometheus, Alertmanager, Grafana, Gatus sidecar, and
Victoria Logs are intentionally not VolSync-backed. Losing them loses telemetry
history or non-declarative UI changes, not the Git source of truth.

Hermes and the AI workbench are intentionally lightweight and stateless. The
Hermes home directory currently lives on `emptyDir`; do not add persistence or
backup coverage for it unless the workbench design changes and the state is
explicitly worth preserving.

## PVC Lifecycle Policy

Protected app PVCs are managed by the same Flux Kustomization as their app. They
are therefore prunable when an app is deliberately removed, and that is the
current cleanup policy. Do not add blanket PVC prune-disable annotations without
a specific migration reason.

Treat app renames, PVC renames, component rewiring, and `APP` substitution
changes as storage migrations rather than ordinary refactors. Before merging
one, verify a recent local and remote backup, decide whether a temporary
prune-disable guard is warranted, and make any destructive PVC deletion an
explicit operator action.

Application PVC capacity is provider-neutral:

- `PVC_CAPACITY` defaults to 5Gi.
- Plex keeps a 50Gi `plex` application PVC.
- Separately declared runtime cache PVCs keep their own capacities and are not
  Kopiur sources; notably, `plex-cache` remains 75Gi.

Kopiur's local and remote persistent mover caches both use
`KOPIUR_CACHE_CAPACITY`, defaulting to 5Gi. This is deliberately independent of
application PVC sizing. The old Plex `VOLSYNC_CACHE_CAPACITY` override sizes
only VolSync's Restic mover cache and disappears with VolSync.

## Composable Population Components

The compatibility component at `kubernetes/components/volsync` combines
independently selectable concerns:

- `volsync/backup`: local and remote Restic `ReplicationSource` objects and
  their credential templates;
- `volsync/restore`: the local `ReplicationDestination` and application PVC
  populated from it;
- `volsync/restore/remote`: a disaster-recovery override composed with
  `volsync/restore` to point that same restore wiring at the existing remote
  Restic repository.

The root `kopiur` component composes the local and remote snapshot concerns
with `kopiur/restore`. The restore concern declares a passive
`Restore` using `source.fromPolicy`, `target.populator: {}`, and
`onMissingSnapshot: Fail`, plus the application PVC whose `dataSourceRef`
consumes that Restore. The Restore selects offset 0, pins that snapshot for the
life of the Restore object, and is recreated without status during a clean
cluster bootstrap so it selects the repository's latest matching snapshot
again. Fail-closed population is deliberate: a missing or mismatched snapshot
must block the protected app rather than silently create blank state.

The app files remain stable during cutover and rollback: every protected app
includes one root `kopiur` line and one root `volsync` line. Only the two root
components change:

| State                  | Kopiur root                    | VolSync root                            |
| ---------------------- | ------------------------------ | --------------------------------------- |
| Pre-cutover            | `local` + `remote`             | `backup` + `restore`                    |
| Current Kopiur cutover | `local` + `remote` + `restore` | `backup`                                |
| VolSync local rollback | `local` + `remote`             | `backup` + `restore`                    |
| VolSync remote DR      | `local` + `remote`             | `backup` + `restore` + `restore/remote` |

The VolSync restore helper and remote override remain in Git, and both
repository credentials remain supplied by `volsync/backup` throughout the
cutover. The remote override gives the destination a distinct
`${APP}-r2-dst` name as well as changing its repository, so an existing
`IfNotPresent` local destination cannot silently retain the local backend.
Because a PVC's `dataSourceRef` is immutable, either rollback still requires
stopping the affected workloads, deliberately deleting their Kopiur-populated
PVCs, and letting Flux recreate them from the selected VolSync composition. Use
local rollback first; add the remote override only if the local Restic
repository is unavailable or untrusted.

After the clean-cluster rebuild passes, the app files drop the VolSync line and
retain only the Kopiur root. The retained helpers are removed only with the
separately approved VolSync retirement.

## VolSync Restore Object Drift

Local `ReplicationDestination` objects use Flux `ssa: IfNotPresent` so Flux does
not continuously update the restore trigger. The cost is that later
`VOLSYNC_*` substitutions, cache-size changes, repository changes, or mover
identity changes do not automatically reach the live restore object.

Before relying on a VolSync restore or starting a Kopiur cutover, compare the
live `ReplicationDestination` with the desired app settings. If it drifted,
refresh the `*-dst` object deliberately in a controlled window before the
restore, then verify the recreated object before touching the production PVC.

## Migration Requirements

A replacement for the current Restic posture must satisfy these requirements:

1. Keep a local target for low-latency restores.
2. Keep a remote object-storage target, currently expected to be Cloudflare R2 or
   an S3-compatible equivalent.
3. Provide explicit, observable Kopia maintenance for every independently
   written repository, and observable replication plus restore verification for
   any mirror.
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
- Treat the remote object-store path separately because it has different
  latency, cost, and failure modes. An independent remote repository needs its
  own maintenance; a replicated mirror instead needs replication status,
  destination-growth monitoring, and direct restore verification.

Do not disable maintenance unless another process is reliably running it and is
observable from the cluster.

## Migration Decision

Kopiur owns backup and passive Restore population for the protected application
fleet. VolSync Restic continues running in parallel as the rollback backup and
retained restore path until the clean-cluster rebuild passes; do not migrate to
VolSync-Kopia as an intermediate step.

The selected rollout is:

1. Keep VolSync and its PVC/populator wiring unchanged throughout Kopiur
   enablement and the two non-Bazarr restore drills.
2. Use Garage S3 as the local Kopiur repository and an independent R2
   repository, with separate credentials, encryption, schedules, retention,
   and maintenance.
3. Require Bazarr to prove scheduled snapshots, quick and full maintenance on
   both repositories, and successful restores from both backends without
   disturbing NFS-dependent workloads.
4. After Bazarr acceptance, enable snapshot-only Kopiur components for the
   remaining apps in one additive fleet PR. Hashed schedules stagger the load;
   VolSync remains the rollback path.
5. Restore TheLounge from Garage and Plex from R2 into isolated temporary PVCs.
   Compare file and byte counts, numeric ownership, applicable database
   integrity, and service-isolation signals without displaying application
   content.
6. Switch the fleet's application PVC population from the VolSync
   `ReplicationDestination` to passive Kopiur Restore objects in one approved
   cutover, while keeping VolSync backup sources active.
7. Require a successful post-cutover incremental Kopiur snapshot, then perform
   the acceptance test: completely tear down cluster state, bootstrap Talos,
   Kubernetes, and Flux normally from Git, and verify that Kopiur discovers the
   existing repositories and repopulates every protected application PVC
   without manually creating Restore, Snapshot, or PVC objects.
8. Remove VolSync only after the rebuilt applications and their data pass
   verification.

The cutover cannot mutate a bound PVC's `dataSourceRef`. It therefore requires
stopping each workload and deliberately deleting and recreating its PVC from
the Kopiur Restore. VolSync retirement remains separate and happens only after
the clean-cluster rebuild and application verification pass.

### Why Not VolSync-Kopia

VolSync-Kopia is no longer the planned migration path. It would be an
intermediate migration from VolSync Restic to a Kopia mover inside the VolSync
model, followed by a later migration to Kopiur if Kopiur becomes the preferred
long-term tool.

That double migration is not worth taking unless Kopiur stalls or proves
unsuitable. The cluster should keep the known-good Restic posture while Kopiur
matures, rather than adopting a transitional backup implementation.

### Why Kopiur

Kopiur is the selected implementation because it is Kopia-native rather than a
retrofit into VolSync's Restic-shaped model. Its design direction better matches
the desired end state: repository resources, separate backup configs and
schedules, restore resources, multiple backends including S3-compatible object
storage, and first-class maintenance.

Kopiur is not yet the sole backup system. Local evidence now includes both
production backends, maintenance, and restore tests; peer testing remains
useful supporting evidence rather than a substitute for those local results.

## Bazarr Production Acceptance

Track the rollout in
[Adopt Kopiur (#1487)](https://github.com/alex-matthews/home-ops/issues/1487).
Bazarr is the first production-acceptance app because it has meaningful
configuration and database state while remaining reconstructable.

The production shape follows
[ADR-0002](../adr/0002-kopiur-backup-storage-shape.md):

- The local repository is S3 served by Garage on the NAS. Kopiur traffic does
  not pass through the NFS daemon.
- The remote repository is independent R2 with its own encryption password,
  schedule, retention, and maintenance. `RepositoryReplication` is not used.
- VolSync remains enabled and continues to own the existing PVC and restore
  wiring.

Both production restore paths have been proven through temporary GitOps
resources. Garage and R2 each restored the latest Bazarr snapshot into an
isolated `ceph-block` PVC; each result contained the expected 21 files with
ownership `1032:100`, and the restored SQLite database passed
`PRAGMA integrity_check`. The restore drills ran during Plex playback:
`nfs_probe` stayed healthy and no zeroscaler event occurred. The R2 drill's full
HPA window showed all eight NAS-dependent apps at one replica. The temporary
Restore, PVC, and validation Job resources were pruned after the evidence was
collected.

Quick and full maintenance have also completed successfully on both
repositories. Because Kopiur 0.8.0 does not reliably populate the Maintenance
status fields, use retained mover Job history and metrics as the evidence.

Phase 2 is accepted. No additional Bazarr R2 run is required: the scheduled R2
write, direct R2 restore, maintenance evidence, and service-isolation test cover
the distinct failure modes. Repetition moves into Phase 3 while VolSync remains
available.

Phase 3 added snapshot-only Kopiur components across the remaining apps while
leaving VolSync untouched. Initial local and remote seeds and later
incrementals are now available for every protected app.

The expedited acceptance sequence supersedes the earlier seven-day Phase 3
wait: the completed two non-Bazarr drills lead to one fleet cutover, one
successful post-cutover incremental, and then the complete teardown/bootstrap
test. Existing soak evidence is retained; these steps do not restart or extend
it. VolSync remains the rollback path until the rebuild passes.

The two non-Bazarr restore gates passed on 2026-07-24:

- TheLounge restored its latest local Garage snapshot into a temporary PVC.
  The restored file and byte counts matched the selected snapshot, ownership
  was `1032:100`, and its SQLite database passed `PRAGMA integrity_check`.
- Plex restored its latest independent R2 snapshot into a temporary 50Gi PVC
  in roughly ten minutes. Both Plex databases passed
  `PRAGMA integrity_check`, and the restored entries were normalised to
  `1032:100`. The filesystem walk was 12 entries and 194 bytes above Kopiur's
  snapshot counters, consistent with preserved symlink metadata.
- Both production applications remained Ready without a drill-induced restart.
  The temporary Restore, PVC, and validation Job resources were pruned through
  GitOps, and the retained local and remote VolSync sources remained successful.

The first validation Jobs exposed harness issues rather than restore failures:
SQLite crash recovery needs a writable temporary clone, Flux substitutions must
be escaped in embedded shell, and validation scripts must be tested with the
target image's shell and utilities. Future drills should validate the
post-substitution script with `flux envsubst --strict` before merge.

App cutover should not proceed until a Kopiur snapshot for that app has
succeeded with non-zero file content. The expected cutover shape is:

1. Confirm the recorded TheLounge/Garage and Plex/R2 restore gates remain
   applicable; rerun only if the restore shape materially changes.
2. Prepare and render the fleet component switch, proving no target PVC
   capacity shrinks.
3. In an explicitly approved window, stop the workloads and delete the old app
   PVCs deliberately.
4. Let Flux recreate each PVC with the Kopiur `Restore` data source.
5. Confirm every Restore and PVC, validate application data, and start the
   workloads.
6. Confirm a later incremental snapshot, then run the complete
   teardown/bootstrap acceptance test before removing VolSync.

After the fleet cutover, update the custom `home-ops-cockpit` Grafana
dashboard. Its Backups stat, dashboard link, and backup branch in Attention
detail currently use only VolSync metrics. During the rollback overlap, add
Kopiur health and freshness signals while retaining the VolSync signals.
Remove the VolSync query branches only when VolSync itself is retired after
the teardown/bootstrap gate.

## Kopiur Known Quirks

Observed during the 0.7.5 pilot and 0.8.0 production acceptance; re-test on
upgrades and file upstream if still present when it next bites:

- A `Repository` whose bootstrap Job has exhausted `backoffLimit` goes
  `Stalled` and is not retried when the spec changes, even though the operator
  observes the new generation — the exhausted Job object (deterministic name
  `<repo>-bootstrap`) blocks it. Recovery: fix the cause, then
  `kubectl delete job <repo>-bootstrap` in the repository's namespace; the
  next reconcile recreates the Job with the current spec.
- Related root cause to know: repository-level movers (bootstrap, maintenance)
  take their identity from `Repository.spec.moverDefaults.securityContext`,
  not from any `SnapshotPolicy` — leave it unset and they run as UID 65532,
  which a UID-owned NFS export will refuse.
- On 0.8.0, `Maintenance` CR status is unreliable even though maintenance
  itself runs correctly: `nextScheduledAt` is documented but never written,
  `lastHandledAt` is skipped for successful runs (`lastRunAt` advances first
  and the next reconcile returns before stamping the completed Job), and
  `consecutiveFailures` has no maintenance-controller writer. Verify
  maintenance outcomes from the mover Job history and metrics, not from the
  `Maintenance` CR status. Still present on upstream `main` as of
  2026-07-23; report upstream rather than working around it in manifests —
  controller-owned status is not GitOps-writable.
- Restore movers emit a non-fatal warning when they cannot read the parent
  `Restore` status with their narrow service-account permissions. Source
  resolution and restore completion still succeed. Do not widen mover RBAC
  locally to silence the warning; report it upstream and re-test on upgrade.
- Persistent mover-cache PVCs are create-only in Kopiur 0.8.0. Changing
  `mover.cache.capacity` affects new claims but does not update an existing
  claim's storage request. Expand an existing cache deliberately through the
  PVC, then expect `FileSystemResizePending` while it is idle; the next mover
  mount completes the filesystem resize. Do not assume a Ready
  `SnapshotPolicy` proves that an existing cache matches its configured
  capacity.
- Deleting a `SnapshotPolicy`/`SnapshotSchedule` (including via Flux prune)
  no longer purges the repository as of kopiur 0.8.0: policy/schedule deletion
  cascades only to the `Snapshot` CRs (`spec.deletion.onPolicyDelete` /
  `onScheduleDelete`, default `Retain` — kopia data preserved), and repo-side
  deletions route through the mass-deletion circuit breaker
  (`Repository.spec.deletionProtection.threshold`, default 10). The pilot's
  interim `defaultDeletionPolicy: Retain` guard from the 0.7.5 era is retired;
  produced snapshots default to `Delete`, so GFS retention prunes repo-side
  again. Kopia snapshots orphaned during the Retain era are re-adopted as
  managed CRs (`origin: adopted`) via the 0.8.0 catalog scan and then age out
  under normal retention.

## Validation Commands

Useful read-only checks:

```sh
kubectl get replicationsource,replicationdestination -A
kubectl get clusterrepository,snapshotpolicy,snapshotschedule,snapshot -A
kubectl -n kopiur-system get maintenance,job
kubectl get persistentvolumeclaim -A
kubectl -n default get hpa
kubectl -n observability get probe nfs -o yaml
kubectl -n default get replicationdestination -o jsonpath='{range .items[*]}{.metadata.name}{" cap="}{.spec.restic.capacity}{" cache="}{.spec.restic.cacheCapacity}{" repo="}{.spec.restic.repository}{" ssa="}{.metadata.labels.kustomize\.toolkit\.fluxcd\.io/ssa}{"\n"}{end}'
```

Current Restic snapshot and restore helpers:

```sh
just volsync list-previous default <app>
just volsync restore default <app> 0
```

Render checks for future manifest changes:

```sh
kubectl kustomize kubernetes/apps/default
mise exec -- flate test all
```

## References

- [Kopiur](https://github.com/home-operations/kopiur)
- [onedr0p/home-ops#11012: deploy Kopiur](https://github.com/onedr0p/home-ops/pull/11012)
