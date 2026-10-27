# Backups

Verified 2026-10-05 against the repository at `main`; not against the live
cluster.

[Data-protection policy](../policy/decisions.md#data-protection) owns coverage
and repository choices. Backup health does not prove restore readiness. For
restoration, follow the
[restore-data skill](../../.agents/skills/restore-data/SKILL.md).

## Coverage

An app's claim is protected when its `ks.yaml` includes the [kopiur
component](../../kubernetes/components/kopiur/kustomization.yaml). Only that
claim is covered, in both repositories; it is 5Gi unless the `ks.yaml` sets
`PVC_CAPACITY`. Caches and other claims an app declares itself, and NAS
mounts, are not protected by association. Zeroscaler, an autoscaler that
scales an app to zero while the NAS probe fails, protects runtime NAS
consumers; it does not cover backup movers.

List the protected apps and the Zeroscaler consumers with:

```bash
# Apps whose claim is protected
git grep -l 'components/kopiur' -- 'kubernetes/apps/*/ks.yaml'
# NAS consumers that Zeroscaler scales to zero
git grep -l 'components/zeroscaler' -- 'kubernetes/apps/*/ks.yaml'
```

Restore testing: the 2026-09-03 full rebuild restored the protected apps from
the local repository. No protected app has an off-site restore test;
PostgreSQL's R2 drills do not fill that gap.

Outside coverage by decision: observability claims; Hermes runtime state, on
a plain claim with no backup; `kritika-postgres`, under the [kritika
database exception](../policy/decisions.md#kritika-database-exception). Garage
setup and upgrades need the operator's NAS runbook, which is not tracked
here; obtain it before a recovery window needs it.

## Maintenance and health

Read the current state first:

```bash
mise exec -- kubectl get clusterrepository,snapshotpolicy -A
mise exec -- kubectl -n kopiur-system get maintenance,job
mise exec -- kubectl describe clusterrepository local
```

Kopia maintenance keeps metadata healthy and reclaims expired storage. Never
disable it to silence symptoms.
[Schedules](../../kubernetes/apps/kopiur-system/kopiur/repository) stagger
starts, not mutual exclusion. A successful Job may have yielded its lease
without doing work: compare actual maintenance timestamps with success logs.
Job TTLs remove evidence; promptly collect or query retained
[logs](observability.md). Missing measurements are not zero.

Verification results and recent snapshots are separate evidence. Existing
persistent cache claims are not proven resized by changing a policy value.
Read repository phase **and condition reasons**: unreachable/missing backends
park work, while probe timeouts may allow maintenance. Pending work can leave
backup-failure alerts quiet, so inspect conditions such as `BackendReachable`,
`MassDeletionHeld` and `Stalled`. No fixed detection time is guaranteed.
Diagnose discovery failures, deletion holds and
missing backends; never bypass health/deletion/reinitialisation guards or
create a replacement repository merely because one is unavailable.
Reinitialisation acknowledges data loss and needs an explicit decision.
