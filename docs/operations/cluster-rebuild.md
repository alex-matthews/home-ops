# Cluster Rebuild

**When to use:** Full rebuild, cold start, teardown, `reset-cluster`, bootstrap sequence, what Flux and kopiur do on an empty cluster, restore drill, rebuild evidence.

How a full teardown and rebuild of this cluster runs, what the control loop
does on a cold start, and which guards make the destructive steps safe. The
bootstrap commands themselves are described operator-side in
[`../../bootstrap/README.md`](../../bootstrap/README.md); backup and restore
posture is in [`storage-and-backups.md`](storage-and-backups.md). Plan every
rebuild with the `maintenance-window` skill: it is a window that holds
imperative state across a merge, and every hold in it is a lease.

The record behind this note is the 2026-09-03 production rebuild, run with
the owner on-site. Timings below are from that run and will vary; the order
of events will not.

## Sequence

1. **Gateway health.** The cluster's network, DNS, and BGP peering depend on
   the gateway. Confirm it is healthy before starting, and stop the window if
   it degrades mid-way; a rebuild behind a failing gateway has no working
   network to come back to.
2. **Pre-flight.** Confirm `main` is the intended baseline and no open pull
   request belongs in it. Run the backup guard (below). Capture a baseline:
   node list, PVC inventory, LoadBalancer addresses, the verification state
   of every OCI source, live container requests, and the latest snapshot per
   protected app. The baseline is what "restored correctly" is measured
   against afterwards.
3. **Teardown.** Drain workloads first (below), then reset every node with
   STATE and EPHEMERAL wiped, into maintenance mode. Ceph's NVMe data is gone
   at this point; recovery is Git plus the repositories only.
4. **Bootstrap.** Apply machine configs, bootstrap etcd, fetch the kubeconfig,
   apply the base manifests and CRDs, sync the helmfile apps, and let Flux
   take over. Sysctl changes committed but never applied land here; verify
   them with `talosctl get kernelparamstatuses` as soon as the secure API
   answers.
5. **Verification.** All Kustomizations and HelmReleases Ready, every OCI
   source with a `verify` block showing `SourceVerified=True`, every passive
   Restore Completed, and the baseline reproduced: addresses, requests, and
   the resolved snapshot per app.

## Guards

Every guard reads fresh state immediately before the step it protects and
fails closed.

- **Backup guard, before teardown.** For every protected app, a Succeeded
  snapshot younger than 24 hours with non-zero size on both repositories.
  Any app missing one on either repository stops the window. Run it at GO
  time, not earlier; the earlier run is evidence, not the gate.
- **Drain before reset.** Concurrent resets wipe the Ceph monitors on the
  first nodes to finish while a slower node is still unmounting RBD volumes;
  that node's unmount then blocks in the kernel and only a power cycle
  recovers it. Resetting nodes one at a time does not help, because quorum
  is lost when the second node wipes and the third node hangs the same way.
  Drain every node so no RBD volume is mapped anywhere, confirm with
  `talosctl mounts` on each node, then reset. `just talos reset-cluster`
  refuses while any node still reports an RBD mount.
- **Parked Restore.** A Restore that fails or stalls during bootstrap is a
  finding to diagnose, never a reason to hand-populate a volume.
- **Verification state.** A source that shows `SourceVerified=False` is a
  finding to assess, never something to bypass.

## What the control loop does on a cold start

Observed on the 2026-09-03 rebuild; the fixes that followed are noted where
they apply.

- **Storage arrives last among the things that need it.** The Rook operator
  image pull dominated: the StorageClass appeared 13 minutes after Flux began
  applying, the Ceph cluster was Ready 4 minutes later and `HEALTH_OK` a
  minute after that. Every consumer of storage had already been applied.
- **Kopiur repositories came Ready before storage.** Discovery adopted the
  repositories' existing snapshots as Snapshot CRs, retention pruned the
  oldest of them immediately, full maintenance started on both repositories,
  and every passive Restore launched its populate pod. None could bind a
  volume, and the 300-second mover startup deadline failed all of them; a
  failed Restore is never retried. Recovery was deleting the Restores so
  Flux recreated them, after which all 18 completed within 8 minutes from
  the local repository, plex last. Since #1983 the repositories depend on
  the Ceph cluster and the deadline is 900 seconds.
- **HelmReleases spent their budget.** App releases failed their 5-minute
  install wait on pods pending for volumes, exhausted two upgrade retries,
  and parked Stalled with `MissingRollbackTarget`. helm-controller does not
  requeue a Stalled release at its interval; each needed
  `flux reconcile hr <name> --reset`. A release whose Kustomization was held
  back by a `dependsOn` edge until storage existed, plex, kept budget and
  recovered unaided. Since #1982 the budget is five retries on install and
  upgrade.
- **Kustomizations that fail early wait a full interval.** One dry-run hit
  the kopiur mutating webhook before it had endpoints and waited an hour.
  Since #1982 every child Kustomization retries after two minutes.
- **The doctrine's instance edges sequenced as designed.** Every operator's
  instance Kustomization waited on its operator and nothing else, and every
  one converged.
- **Hourly snapshot schedules fire during the gap.** One fired against a
  still-pending volume and failed; the alerts cleared after the next
  successful run. Harmless.
- **ARC's listener can bind to a runner set that is replaced a second
  later.** The controller created a runner set, a listener for it, then
  replaced the set on a spec-hash change without regenerating the listener,
  which crash-looped until the AutoscalingListener object was deleted and
  recreated by the controller. Runbook step; no fix in Git.
- **Objects that only ever existed live are gone.** Resource requests on the
  Ceph CSI plugin pods were residue of an earlier deployment path and are not
  declared in Git; the rebuild reproduced Git exactly.
- **The read-only agent identity's token is reissued.** Flux recreates the
  ServiceAccount token Secret with new data, so the read-only kubeconfig is
  Unauthorized until the operator re-extracts the token. The read-only Talos
  identity, signed by the persistent machine CA, keeps working.

## Verifying the restores

"The app started" proves nothing about its data. Three records per app
should agree: the latest snapshot recorded before teardown (name, time,
size), the newest snapshot the repository holds for that identity once
adopted (time, size, kopia ID), and the ID the Restore resolved. A fourth,
the first scheduled snapshot kopia takes of the restored volume, is an
independent read of what landed: its size should match the pre-teardown
size within normal app churn, and kopia's small "new files" count means it
found the rest metadata-identical.

Two shrink patterns are benign and worth knowing before they alarm anyone:
an `emptyDir` mounted over a directory of the restored volume hides that
directory from an in-pod `du`, and a WAL-mode SQLite application checkpoints
and truncates a write-ahead log on first start. On the 2026-09-03 rebuild
one application's snapshots were 174 MB for weeks while its database, inside
its own weekly backups, was a constant 20 MB: the difference was the
un-checkpointed log, applied and truncated at first start.

Content checks the operator does through the application UIs stay the last
word on the apps that matter most.
