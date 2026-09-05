# Storage and Backups

Current storage and backup posture. Update it when backup topology changes,
after restore drills, or when the operational rules below stop holding.

## Current Posture

Persistent application data lives on Rook-Ceph `ceph-block` PVCs. Some
media-adjacent workloads also mount Synology NAS storage over NFS at runtime.

Kopiur is the only backup system. It provides both the snapshot path and the
passive `Restore` population path for every protected application PVC (what
a cold cluster does with them is in
[`cluster-rebuild.md`](cluster-rebuild.md)):

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
off-site. Kopiur's `SnapshotReplication` CRD does not change that decision:
feeding R2 from Garage would make the off-site path depend on the local
repository, while running replication alongside the direct R2 policies would
create overlapping writers for the same kopia identities.

Ceph authentication runs on aes256k keys only. Every cephx entity was rotated
to generation 2 after the Talos 1.14.0 rollout supplied the kernel support,
the CSI keys with a rolling drain of each node so that no mount kept the
prior key, and `allowedCiphers` is restricted to `aes256k` in the rook
cluster HelmRelease. A future entity on a legacy key surfaces as a Ceph
health warning; nothing mutes it.

## The Retired VolSync Archive

The fleet cut over to Kopiur on 2026-07-25; VolSync itself was removed on
2026-07-31, once post-cutover incrementals and fleet-wide database integrity
verification had passed. It ran alongside Kopiur for that week, so Kopiur's own
repositories already cover every point in time from the cutover onward. What
the VolSync archive uniquely holds is history from before it.

Its R2 Restic repositories are retained: one per app, at `<repository>/<app>`,
where the base came from the template the retired remote `ExternalSecret`
supplied. That manifest is in Git history at
`kubernetes/components/volsync/backup/remote/externalsecret.yaml` and names the
1Password item and the fields to read from it.

Recovery is the restic CLI pointed straight at a repository — VolSync does not
need to be redeployed, and the earlier guidance to restore its manifests from
Git history no longer applies. All nineteen repositories were verified with
`restic check` on 2026-08-02, and one additionally with `--read-data-subset=5%`.

The matching local repositories, and the MinIO instance on the NAS that hosted
them, were removed at the same time. They carried the same seven dailies plus
intra-day granularity from VolSync's final day — a window Kopiur independently
covers, so nothing unique was lost.

`RESTIC_PASSWORD` from that 1Password item is the only key to this archive.
Restic cannot open a repository without it and there is no recovery path, so
the item outlives the manifests that used to consume it.

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
by design.

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

Both policies carry kopiur's built-in verification (#1985): the local
policy runs a quick blob check daily with 5% of file content read in full
and a deep scratch restore of the latest snapshot monthly into
node-ephemeral storage; the remote policy runs the quick check weekly on
the default blob check only. A tier passes when the verified snapshot has
files and no errors. The chart ships no verification alert, so
`kopiur-verification` in `kopiur-system` alerts on a stale verified
timestamp and on a policy with backups but no verification at all. Kopiur
runs the first due slot as soon as verification is added to a policy that
already has a backup, so a merge that adds a tier starts Jobs immediately.

Every policy mover, backup and verify, shares a 5 Gi cache claim, and
kopia's default content and metadata cache budgets are 5000 MiB each, more
than the claim holds; both policies cap them at 2048 MiB and 1024 MiB.
Without the cap a deep verify of plex fills the claim and fails with no
space left on device (observed 2026-09-05). Restore movers set no cache and
run on a node emptyDir, so they are unaffected either way.

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

## Retiring An App

Retirement is two separate acts ([ADR-0005](../adr/0005-backup-lifecycle-on-app-retirement.md)).

Removing an app from Git keeps its backups. Flux prunes the policy and
schedule; kopiur keeps every snapshot and shows them as `discovered` rows
forced to `Retain`. Nothing in the cluster can delete them and nothing needs
deciding at removal time. Kept snapshots still occupy repository space.

Deleting a retired app's backups is one recipe, run under the administrative
profile with 1Password available:

```sh
just kube retire-backups <app>              # report: rows per repository
just kube retire-backups <app> delete=true  # delete, after a confirmation
```

The recipe refuses while the app's Kustomization or PVC exists, or while any
policy resolves to the app's identity. Report mode reads only Kubernetes. In
delete mode it works one repository at a time, re-running the guards first:
kopia connects from the workstation with credentials injected for that one
command, the repository's own listing for the identity must equal the rows or
nothing is deleted, the snapshots are deleted by source, a second listing
proves they are gone, and a catalog scan is requested and waited for so the
rows expire. Each step is written to a ledger under the local state
directory. Kopia's config file holds the keys while it runs, so it lives in a
temporary directory removed on exit.

Kopiur is not driven and its breaker is not involved: deletion happens in the
repository and kopiur only observes it. Once a repository's deletion has run
there is no rollback; the confirmation is the authorisation. Space returns at
that repository's next full maintenance.

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

## Repository Health And The Circuit Breaker

From chart 0.9.3 the backend health probe is on by default and doubles as a
circuit breaker: after three consecutive failed connects (default probe
interval 30m) a repository moves to `Degraded`, and snapshots, maintenance,
replication, and restores against it park until a connect succeeds. Parked
work is deferred, not lost — schedules default to `Forbid`, so at most one
snapshot per policy waits, and it fires once on recovery. Recovery is
automatic: while open, the repository retries its connect on a 120s–600s
backoff, so it heals within minutes of the backend returning. `Degraded` maps
to kstatus `Reconciling`, so Flux waits rather than failing the Kustomization.

Neither `ClusterRepository` sets `spec.health.probe`; the defaults are
deliberate. `onFailure: Alert` restores the pre-0.9.3 alert-only behaviour and
`enabled: false` disables probing entirely — set either only with a reason.

Operationally this means `<repo>-discovery` connect Jobs appear in
`kopiur-system` every 30 minutes per repository, repositories can leave
`Ready` without a spec change, and a backend outage of 15+ minutes fires both
`KopiurRepositoryBreakerOpen` (warning) and `KopiurRepositoryNotReady`
(critical) from the chart's PrometheusRule. During an outage, parked snapshots
sit `Pending` rather than failing, so backup-failure signals stay quiet; watch
the repository phase and breaker metrics instead.

## Known Quirks

Rechecked on 2026-09-02 against 0.10.6 source. The live rollout verified
repository, policy, schedule and backup paths; maintenance and restore quirks
below remain source-verified rather than re-exercised. Re-test runtime
observations after upgrades and file upstream if one still bites.

- Repository-level movers take their identity from
  `spec.moverDefaults.securityContext`, not from any `SnapshotPolicy`. Left
  unset they run as UID 65532.
- `Maintenance` CR status is incomplete even though maintenance runs correctly.
  `lastRunAt` is not a reliable success authority either: on 0.10.6 both
  repositories' full maintenance Jobs succeeded on the 2026-09-03 rebuild and
  the field stayed absent on both fresh CRs. `lastHandledAt` is a yield
  marker and stays absent on a healthy repository (unchanged in 0.10.0 — do
  not wait for it to appear). `nextScheduledAt` and `consecutiveFailures`
  have no writers, and `lastContentReclaimedBytes` is hard-coded to zero, as
  is the gauge mirroring it. There are no maintenance success or duration
  metrics, and mover metrics are OTLP-push-only and not exported here. Verify
  from Job history — `kube_job_status_succeeded` keeps it after the Job
  self-reaps one hour after finishing.
- `Restore` exposes `status.progress`, but the mover deliberately does not
  populate it as of 0.10.0, and terminal status carries no stats. Verify a
  restore from the target PVC's contents, not from CR counters.
- A repository whose `<repo>-discovery` Job exhausted `backoffLimit` on a
  terminal-class failure (bad credentials, locked repository) parks
  `Failed`/`Stalled`. From 0.10.0, a spec edit changes the repository generation
  and immediately recycles a stale generation-stamped Job. A Secret-only
  credential fix does not change the generation and still waits for the
  finished Job's TTL, one hour by default; deleting the Job retries
  immediately. One terminal Job created before the 0.10.0 upgrade has no
  generation stamp and can behave the old way once. From 0.9.3, outage-class
  failures instead recycle automatically into the `Degraded` retry loop and
  need no intervention.
- Persistent mover-cache PVCs are create-only. Changing `mover.cache.capacity`
  affects new claims only; expand an existing cache through the PVC and expect
  `FileSystemResizePending` until the next mover mount completes the resize. A
  Ready `SnapshotPolicy` does not prove its cache matches configured capacity.
- Deleting a `SnapshotPolicy`/`SnapshotSchedule`, including via Flux prune,
  cascades only to `Snapshot` CRs (`onPolicyDelete`/`onScheduleDelete`, default
  `Retain`). Repository-side deletions route through the mass-deletion circuit
  breaker (`deletionProtection.threshold`, default 10); ten or more
  unacknowledged external deletions hold the snapshots with `DeletionHeld=True`
  and surface `MassDeletionHeld=True` on the repository until it is annotated
  `kopiur.home-operations.com/allow-mass-deletion=<RFC3339>`.
- A mover pod that cannot start within
  `spec.failurePolicy.podStartupDeadlineSeconds` (300 by default) fails its
  run, and a failed `Restore` is never retried. On a cold cluster the
  populate pods launch as soon as the repositories are Ready, so a
  StorageClass that arrives later than the deadline parks every restore
  `Stalled`. The restore component sets 900 and the repositories depend on
  the Ceph cluster since #1983; recovery from a parked restore is deleting
  the `Restore` so Flux recreates it without status.
- On a cold cluster a repository adopts its existing snapshots as
  `origin=adopted` Snapshot CRs (policy reference and identity labels set,
  no schedule ownership), applies GFS retention to them immediately, and
  starts full maintenance on both repositories while restores are in
  flight. All of it is safe — kopia maintenance only reclaims content nothing
  references — and all of it is noise to expect, not a fault.
- `kubectl kopiur ls`, `cat`, `download`, and `browse` derive the credential
  Secret's namespace from the repository's `secretRef`, and refuse a session
  pod in any other namespace even when the secrets component projects the
  same-named Secret there. Their suggested workarounds move credentials; a
  scratch restore into a throwaway PVC is the credential-free alternative.
- From 0.8.1 the chart's `ServiceMonitor` sets `honorLabels: true`, so
  `kopiur_*` series carry the CR's namespace. Write queries against
  `namespace`, not `exported_namespace`.
- A rook chart bump does not by itself roll the CSI plugins. Rook writes the
  ceph-csi image into the `rook-csi-operator-image-set-configmap` ConfigMap
  that the CSI operator reads, but ceph-csi-operator (1.0.4) does not watch
  that ConfigMap: Driver reconciles run on Driver or OperatorConfig changes,
  on owned objects, or on the controller's periodic resync. On 2026-09-04
  rook v1.20.7 wrote cephcsi v3.17.1 and the plugins stayed on v3.17.0 for
  hours. Check the plugin image before relying on a new CSI capability such
  as aes256k keys; restarting the `ceph-csi-controller-manager` Deployment
  forces the roll.
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

An in-pod `du` smaller than the snapshot is not by itself a failed restore.
An `emptyDir` mounted over a directory of the volume hides that directory,
and a WAL-mode SQLite application checkpoints and truncates its write-ahead
log on first start. Compare against the application's own artefacts (its
periodic backup archives, if it keeps them) or the first scheduled snapshot
kopia takes of the restored volume before concluding data is missing.

## Restore Drill Record

- **2026-09-03**, full production rebuild, all protected apps at once,
  populated from the local repository. Every Restore resolved the newest
  snapshot the repository held for its identity — matched against the
  pre-teardown snapshot record by name, time, and size, and the resolved
  kopia IDs — and the first post-restore scheduled snapshot of each volume
  matched its pre-teardown size within normal churn. First pass failed for
  every app on the mover startup deadline because storage arrived late
  (fixed by #1983); second pass completed in 8 minutes from the local
  repository. Content spot-checked through the application UIs for the
  media apps. Two on-disk shrinks investigated and explained (an `emptyDir`
  over a log directory; a SQLite WAL checkpoint). Method and evidence:
  [`cluster-rebuild.md`](cluster-rebuild.md).

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
