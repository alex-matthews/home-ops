# Node Upgrades

Verified 2026-10-05 against the repository at `main`; not against a live
rollout.

Tuppr owns Talos and Kubernetes version rollouts. Machine-configuration
changes belong to [talos/README](../../../../talos/README.md); boot failures
to [node boot](../../../../docs/recovery/node-boot.md).

## How a rollout runs

Merging a bump under [tuppr/upgrades](../../../../kubernetes/apps/system-upgrade/tuppr/upgrades)
requests the rollout. The current policy pre-pulls installers and upgrades
one node at a time. Before each batch, its health checks require no Running
Kopiur Snapshot, no Resolving or Restoring Restore, and Ceph `HEALTH_OK`.
Read resource status and those conditions when progress stops. The gate
delays upgrades; it does not suspend backup schedules or prevent a backup
starting after the check. Inspect affected backups afterwards.

Check the declared policy before relying on this sequence: parallelism or
pre-hooks can change it. The [controller](https://redirect.github.com/home-operations/tuppr/blob/2d0f0311a8fc2f3cdd639f441b88fe22efd7f32d/internal/controller/talosupgrade/upgrade.go)
was checked at Tuppr 0.5.7; this is not a live rollout result.

## Before merging

Read the target release notes and support matrix. For a Talos minor, check
etcd format and downgrade restrictions, resolver/time-sync changes and new
configuration document kinds. Arrange a verified recovery snapshot before
crossing an irreversible format change; credential-bearing snapshots are
human-only work. Validate the first upgraded node before continuing, and
migrate configuration only after nodes support its document kinds.

A Kubernetes upgrade is a separate change, made only once every node's
Talos release supports the target. Expect possible API interruption; inspect
upgrade status and component health rather than relying on elapsed time.

## Completion

Verify every node's intended version and component health, restored scheduling,
Ceph health and affected backups before closing the rollout. When progress
stops, follow [failed upgrades](#failed-upgrades); a retry is not itself
recovery.

## Failed upgrades

Inspect the failed upgrade, node, etcd and Ceph state and remaining redundancy.
Hold further drains and storage changes until recovery. Kubernetes `Ready`
does not establish etcd or Talos machine health. Stop and diagnose unexpected
state; a previously successful cold boot is not an automatic remedy.

Once the recovery is explicitly approved, recover the node, verify its
running version and API/etcd health, check cordon/taint state, and restore
scheduling as authorised. Require Ceph `HEALTH_OK` before proceeding. Resetting
Tuppr with its `tuppr.home-operations.com/reset` annotation is a separate live
mutation requiring approval after those checks; do not treat retry as recovery.
Use [observability](../../../../docs/operations/observability.md) for alerts
and retained Job logs.

## Reboots and workload placement

The [reboot-node recipe](../../../../talos/mod.just) cordons and drains, waits
for Talos readiness and a changed boot ID, then uncordons. Its drain deletes
emptyDir data: include that loss in the exact approval. It has no Ceph or
application-health gate, so require their recovery before another disruption.
A fast kexec reboot may evade a sampled Node `NotReady` transition.

The [descheduler policy](../../../../kubernetes/apps/kube-system/descheduler)
balances requested CPU and memory with bounded evictions, excluding
unschedulable destinations. Check classification/eviction logs and requests,
not pod counts; convergence is not guaranteed. Keep eviction and placement
on compatible signals when changing this policy. Tuppr's outdated-node taint
is a scheduling preference, not a hard destination ban.
