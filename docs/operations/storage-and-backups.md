# Storage and Backups

This document captures the current storage and backup posture and the selected
direction for a future Kopiur migration. It is intentionally short-lived and
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

Linux storage permissions are numeric. Names such as `docker`, `node`, or
`admin` are only labels on the system that defines them. For backups and
restores, keep three identities separate:

- the app data owner: the UID/GID that owns files in the source PVC;
- the mover identity: the UID/GID used by the backup or restore job;
- the NAS/export identity: the UID/GID or server-side mapping used by NFS paths
  when the app or backup repository touches Synology storage.

The current default for VolSync-backed apps is `1032:100` for both the app pod
and the VolSync Restic movers. This matches the NAS-side `docker` convention and
keeps most single-app PVC backup and restore paths unprivileged in principle.
It is this cluster's convention, not a Kopiur requirement.

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

## Backup Inventory

This inventory is derived from the currently included resources in
`kubernetes/apps/default/kustomization.yaml`.

| App           | VolSync local | VolSync remote | Runtime NAS | Zeroscaler | Notes                                                         |
| ------------- | ------------- | -------------- | ----------- | ---------- | ------------------------------------------------------------- |
| `agregarr`    | yes           | yes            | no          | no         | Default VolSync capacity.                                     |
| `atuin`       | yes           | yes            | no          | no         | 1Gi VolSync capacity; optional Kopiur smoke test.             |
| `autobrr`     | yes           | yes            | no          | no         | Default VolSync capacity.                                     |
| `bazarr`      | yes           | yes            | yes         | yes        | First real Kopiur pilot; NAS availability controls app scale. |
| `brrpolice`   | yes           | yes            | no          | no         | Default VolSync capacity.                                     |
| `maintainerr` | yes           | yes            | no          | no         | Default VolSync capacity.                                     |
| `plex`        | yes           | yes            | yes         | yes        | Custom VolSync capacity and cache; separate `plex-cache` PVC. |
| `prowlarr`    | yes           | yes            | no          | no         | Default VolSync capacity.                                     |
| `qbittorrent` | yes           | yes            | yes         | yes        | NAS availability controls app scale.                          |
| `qui`         | yes           | yes            | yes         | yes        | NAS availability controls app scale.                          |
| `radarr`      | yes           | yes            | yes         | yes        | Separate `radarr-cache` PVC.                                  |
| `radarr-se`   | yes           | yes            | yes         | yes        | Separate `radarr-se-cache` PVC.                               |
| `recyclarr`   | yes           | yes            | no          | no         | CronJob workload; default VolSync capacity.                   |
| `resolute`    | yes           | yes            | no          | no         | Default VolSync capacity; single-writer SQLite API.           |
| `sabnzbd`     | yes           | yes            | yes         | yes        | NAS availability controls app scale.                          |
| `seerr`       | yes           | yes            | no          | no         | Separate `seerr-cache` PVC.                                   |
| `sonarr`      | yes           | yes            | yes         | yes        | Separate `sonarr-cache` PVC.                                  |
| `tautulli`    | yes           | yes            | no          | no         | Separate `tautulli-cache` PVC.                                |
| `thelounge`   | yes           | yes            | no          | no         | Check SQLite message history before Kopiur.                   |

Zeroscaler protects apps that need NAS access at runtime. It does not protect a
backup mover job by itself. If a future local Kopia target uses NFS only inside
backup jobs, protect that path with backup scheduling, alerts, restore tests, and
maintenance monitoring rather than by scaling unrelated app workloads.

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

VolSync-backed app PVCs are managed by the same Flux Kustomization as their app.
They are therefore prunable when an app is deliberately removed, and that is the
current cleanup policy. Do not add blanket PVC prune-disable annotations without
a specific migration reason.

Treat app renames, PVC renames, component rewiring, and `APP` substitution
changes as storage migrations rather than ordinary refactors. Before merging
one, verify a recent local and remote backup, decide whether a temporary
prune-disable guard is warranted, and make any destructive PVC deletion an
explicit operator action.

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

VolSync Restic remains the working backup system. Do not migrate to
VolSync-Kopia as an intermediate step.

The selected Kopia-backed migration path is Kopiur, after it has proved itself
enough for this cluster:

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

Use Bazarr as the first real Kopiur pilot. Track the adoption in
[Adopt Kopiur (#1487)](https://github.com/alex-matthews/home-ops/issues/1487).
Bazarr has meaningful configuration and database state while remaining
low-consequence and reconstructable. Atuin is still suitable for an optional
control-plane smoke test, but its PVC is not yet representative while the app
has little workstation use. Resolute is also low-risk, but shadow-mode traffic
currently gives it too little state and churn to prove much beyond plumbing.

The install gate is a tagged Kopiur release containing the merged correctness
fixes in [#252](https://github.com/home-operations/kopiur/pull/252) and the
adjacent controller work in
[#251](https://github.com/home-operations/kopiur/pull/251) and
[#253](https://github.com/home-operations/kopiur/pull/253). Do not deploy an
untagged `main` build. Re-check the current chart, CRDs, and examples at install
time because the project is still moving quickly.

The first pilot PR should stay backup-only:

- Install Kopiur in a dedicated operator namespace with cluster scope only if
  `ClusterRepository` is used.
- Use a new dedicated Synology NFS path as the first local repository. This is
  an experiment that isolates Kopiur evaluation from deploying another storage
  service; it does not select inline NFS as the production backend.
- Keep VolSync Restic enabled and do not change the existing `bazarr` PVC,
  `dataSourceRef`, storage class, app UID/GID, or restore wiring.
- Add only a `SnapshotPolicy` and `SnapshotSchedule` for the existing `bazarr`
  PVC after the repository is ready.
- If using a shared `ClusterRepository`, enable credential projection only with
  all three gates present: chart RBAC, repository owner allow, and Bazarr consumer
  opt-in.
- Prove two snapshots, including one after a verified application-generated
  change, then restore into a temporary PVC before any app cutover work.

Inline NFS is intentionally provisional. [Kopia warns](https://kopia.io/docs/advanced/consistency/)
that network filesystems may not provide the required crash and partition
consistency, while introducing Garage would add a separate service and metadata
lifecycle to the first test.
After the local proof, compare inline NFS with Garage S3 using the measured
maintenance and restore evidence before selecting the wider local-backup shape.

### Remote R2 Posture

Kopiur supports two valid off-site shapes:

- `RepositoryReplication` copies the local repository's encrypted blobs to R2.
  It avoids a second PVC snapshot and chunking pass, shares the source repository
  format and encryption password, and produces a restore-ready mirror. Its main
  cost is shared fate: corruption or a destructive source operation may be
  propagated depending on sync settings.
- An independent R2 repository snapshots the PVC separately and has its own
  repository format, password, retention, and maintenance. It provides stronger
  isolation from local-repository corruption or maintenance mistakes, at the
  cost of a second backup pipeline, duplicate source work, and another
  maintenance lifecycle.

The recommended initial remote posture, after the local snapshot, maintenance,
and restore gates pass, is `RepositoryReplication` to R2 with
`deleteExtra: false`. This is the safer initial deletion posture:
destination-only blobs are retained rather than pruned when they disappear from
the source. Tune parallelism only after measuring the initial seed, and prove
the destination by attaching it as a recovery repository and restoring into a
temporary PVC. A successful replication status alone is not restore evidence.
See the
[Kopiur replication](https://github.com/home-operations/kopiur/blob/main/docs/replication.md)
and [Kopia synchronization](https://kopia.io/docs/advanced/synchronization/)
semantics.

After repeated snapshots, maintenance runs, replications, and direct R2 restores,
choose the long-term posture:

- Keep additive replication when its growth and restore performance are
  acceptable. This remains the default recommendation.
- Consider `deleteExtra: true` only if an exact, compact mirror is worth allowing
  source-side deletions to prune R2 on the next sync.
- Use an independent R2 repository instead when isolation from local repository
  corruption or maintenance errors is more important than the extra jobs,
  PVC reads, repository state, and maintenance.

This remote choice is separate from the later inline-NFS-versus-Garage decision
for the local repository.

Bazarr is large enough to validate a real application restore but too small to
stress the spinning-disk NAS. If backend performance is still uncertain, use a
separate throwaway PVC with a mixed synthetic dataset for that test. Keep it
outside the Bazarr application resources so synthetic load cannot be mistaken
for protected app state.

Pilot success means:

- The existing Restic backup remains untouched.
- Initial and changed-data Kopiur snapshots complete to the local target, and a
  second low-change snapshot demonstrates expected deduplication behavior.
- Quick and full maintenance complete with observable status, recorded runtime,
  and no unacceptable interference with media workloads.
- A restore into a temporary PVC preserves expected ownership and files, and
  the restored Bazarr database passes an integrity check.
- `RepositoryReplication` completes to R2 with `deleteExtra: false`, reports
  useful status, and has measured initial-seed and incremental runtimes.
- The R2 destination is attached as a recovery repository and completes a
  temporary-PVC restore; replication status alone does not satisfy this gate.
- If used, the synthetic test records snapshot and maintenance duration, data
  shape, repository growth, and NAS impact separately from the app test.
- Rollback is simply deleting the pilot Kopia resources.

App cutover should not proceed until a Kopiur snapshot for that app has
succeeded with non-zero file content. The expected cutover shape is:

1. Scale the app down.
2. Delete the old app PVC deliberately.
3. Let Flux recreate the PVC with the Kopiur `Restore` data source.
4. Confirm the restored PVC contents.
5. Scale the app back up.

## Kopiur Known Quirks

Observed on 0.7.5 during the pilot rollout (2026-07-18); re-test on upgrades
and file upstream if still present when it next bites:

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
flate test all -p ./kubernetes/flux/cluster --allow-missing-secrets
```

## References

- [Kopiur](https://github.com/home-operations/kopiur)
- [onedr0p/home-ops#11012: deploy Kopiur](https://github.com/onedr0p/home-ops/pull/11012)
