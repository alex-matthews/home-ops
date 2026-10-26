# Node Upgrades

Verified 2026-10-05 against the repository at `main`; not against a live
rollout. The health checks and the stop procedure were re-checked on
2026-10-26 against Tuppr 0.5.10 and talosctl v1.14.2 source.

Tuppr owns Talos and Kubernetes version rollouts. Machine-configuration
changes belong to [talos/README](../../../../talos/README.md); boot failures
to [node boot](../../../../docs/recovery/node-boot.md).

## How a rollout runs

Merging a bump under [tuppr/upgrades](../../../../kubernetes/apps/system-upgrade/tuppr/upgrades)
requests the rollout. The current policy pre-pulls installers and upgrades
one node at a time. Its health checks require no Running Kopiur Snapshot, no
Resolving or Restoring Restore, Ceph `HEALTH_OK`, every CNPG cluster in its
healthy phase with all instances ready, and every node Ready and not cordoned.
They run before each Talos node, but for a Kubernetes upgrade only before its
Job starts, not while it runs. A failing check holds the rollout rather than
failing it. Read resource status and those conditions when progress stops.
The gate delays upgrades; it does not suspend backup schedules or prevent a
backup starting after the check. Inspect affected backups afterwards.

The CNPG check is a readiness gate; it does not measure replication lag. A
cordoned node, whether cordoned deliberately or left so by a failed Job, holds
an upgrade at its next check until the owner decides whether to uncordon it.

Check the declared policy before relying on this sequence: parallelism or
pre-hooks can change it. The [controller](https://redirect.github.com/home-operations/tuppr/blob/ca8bf1e1cfea73d6ebcbd0face6c73b75be46a73/internal/controller/talosupgrade/upgrade.go)
was checked at Tuppr 0.5.10; this is not a live rollout result.

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
Ceph and CNPG health and affected backups before closing the rollout. When
progress stops, follow [failed upgrades](#failed-upgrades); a retry is not
itself recovery.

## Failed upgrades

Inspect the failed upgrade, node, etcd and Ceph state and remaining redundancy.
Hold further drains and storage changes until recovery. Kubernetes `Ready`
does not establish etcd or Talos machine health. Stop and diagnose unexpected
state; a previously successful cold boot is not an automatic remedy.

To stop a Talos rollout before touching a node mid-run, get approval to
suspend the TalosUpgrade and delete its upgrade Jobs. Add the
`tuppr.home-operations.com/suspend` annotation (any value suspends; only
removing it resumes) and wait until the TalosUpgrade shows phase `Pending`
with reason `Suspended`: until then, a check already running can still start
the next node. Then delete its upgrade Jobs in the foreground
(`--cascade=foreground --wait=true`) and confirm their Pods have terminated;
hold node work until they have. Deleting a Job does not cancel an upgrade
Talos has already accepted. Before touching the node, establish its actual
state. The annotation is not in Git: after Flux next applies
`tuppr-upgrades`, confirm it remains and the TalosUpgrade still shows phase
`Pending` with reason `Suspended`.

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
