# Node Upgrades

How Talos and Kubernetes version bumps roll through the nodes, what a healthy
rollout looks like, which side effects are expected rather than incidents,
how workloads respread afterwards (scheduling, descheduler policy), and what
persists when a rollout fails mid-way. Baseline observations are from the
2026-08-06 Talos 1.13.7 → 1.13.8 rollout, the 1.13.8 → 1.13.9 rollout
(2026-08-21 to 08-27), which a node firmware hang split across six days, and
the 2026-09-04 1.13.9 → 1.14.0 rollout, which ran unattended in 20 minutes.

## How a rollout runs

Tuppr owns node upgrades. Merging a version bump to
`kubernetes/apps/system-upgrade/tuppr/upgrades/` is the whole trigger: tuppr
pre-pulls the installer image on every node, then upgrades one node at a time,
rebooting each and holding between nodes until its health checks pass. The
checks are declared on the `TalosUpgrade`/`KubernetesUpgrade` CRs: no Kopiur
`Snapshot` in phase `Running`, no `Restore` resolving or restoring, and the
Ceph cluster reporting `HEALTH_OK`. A rollout that appears stalled between
nodes is usually a gate doing its job — check those three before suspecting
tuppr.

The 1.13.8 rollout took roughly ten minutes per node including the Ceph
recovery window; the 1.14.0 rollout took about seven, with each node
`NotReady` for roughly two minutes. tuppr pre-pulls the installer image
before cordoning the first node, so the reboot window does not include image
download time. On a release day the Image Factory builds the installer for a
given schematic on first request, and the first pre-pull attempt can time out
with "no pull progress ... registry may be failing requests" while that build
runs; tuppr retries on its own and the second attempt pulls normally
(observed 2026-09-04, about a minute apart).

## Before merging a Talos minor

The tuppr gates cover Ceph and backups, not the version-specific facts, so
read the release notes for these before merging the Renovate group PR:

- A bundled etcd major (1.14 moved 3.6 to 3.7) makes the Talos minor a
  one-way door: once the first member has written the new format there is no
  downgrade, and recovery is an etcd snapshot restore. Take and verify one
  first (`talosctl etcd snapshot`, kept under the gitignored `.private/`).
  The cluster runs mixed member versions until the last node completes and
  then advances the storage version on its own.
- Resolver and time-sync defaults can change. 1.14 started applying the DHCP
  lease's domain (`internal` here) to the host resolver, which the kubelet
  appends to every pod's search list, and turned on NTS for the default time
  server, which needs TCP 4460 egress. Both were verified harmless here; check
  a pod's `resolv.conf` and `talosctl get timestatus` on the first node.
- Machine-configuration deprecations do not block an upgrade, but new
  document kinds are rejected by nodes still on the old minor, so config
  migrations follow the rollout rather than accompanying it.

## Kubernetes upgrades

A `KubernetesUpgrade` bump is a separate merge from the Talos one and needs
no reboots: tuppr replaces the static control-plane pods one component at a
time across the nodes, apiserver first, then controller-manager, then
scheduler, then restarts the kubelets. The 2026-09-04 v1.36.4 → v1.37.0
upgrade took six minutes end to end with every Flux object Ready throughout
and Ceph untouched. Upstream notes an API blip while apiservers roll
(siderolabs/talos#14227); none was observed here. Merge it only once every
node runs a Talos release whose support matrix includes the target minor.

## Expected side effects per node

- The node goes `NotReady` for the reboot; Ceph dips to `HEALTH_WARN` while
  its mon and OSD are down and while PGs re-sync afterwards.
- Mon/OSD-down alerts for the rebooting node fire and self-resolve. If the
  node hosted a Ceph mgr, alert annotations can briefly render as "error
  expanding template" — see the alert caveats in
  [`../guides/validation.md`](../guides/validation.md).
- Kopiur is unaffected: the repositories are NAS- and R2-backed, both stayed
  `Ready` through the 1.13.8 rollout, and the circuit breaker did not trip.
  Backups due mid-rollout are deferred by the tuppr gate, not lost.

## After the rollout: workload spread

The last node upgraded ends the rollout nearly empty — everything drained off
it has been rescheduled onto the earlier nodes, and nothing moves back on its
own. The descheduler's `LowNodeUtilization` profile
(`kubernetes/apps/kube-system/descheduler/`) restores balance on the same
signal the scheduler places by: requested CPU and memory, as deviation bands
of ±10 points around the fleet mean. A node below the lower band on every
resource is a target; each node above the upper band on any resource sheds up
to five pods per five-minute cycle. Because eviction and replacement
placement optimise the same quantity, the post-rollout burst converges
rather than looping: a workload may hop more than once while the fleet
re-levels, but each eviction hits a fresh replacement pod, and the burst
ends once every node is inside the bands.

Rebalancing toward a returning node cannot begin while tuppr's cordon holds:
the descheduler never targets an unschedulable node, and tuppr uncordons
only once the node's health checks pass. Its
`tuppr.home-operations.com/outdated` taint is `PreferNoSchedule` — invisible
to the descheduler, but scored against by the scheduler, which biases
replacement placement away from not-yet-upgraded nodes. An "underutilized
node, zero evictions" reading mid-rollout is sequencing, not a fault.

Convergence is deliberately gradual — expect balance within a few cycles, not
immediately. Verify with the descheduler's own log (node classifications and
`totalEvicted`), not pods-per-node counts: pod count is not part of the
policy, so uneven counts with every node inside the request bands is the
policy working, not failing.

The policy balances on requests deliberately. Its predecessor balanced on
actual utilisation and pod count — signals the scheduler does not place by —
and evicted the same pods from the same node every five minutes for over a
day while the scheduler put every replacement straight back (#1805). A future
policy change should keep eviction and placement on one signal or expect the
same loop.

## When a node stays down

A node that hangs at its upgrade reboot (firmware signature, diagnostics,
and BIOS notes: [`node-firmware-and-boot.md`](node-firmware-and-boot.md))
leaves the rollout in a stable but non-obvious state. Observed across the
six-day 2026-08-21 outage:

- tuppr retries the node's upgrade job, marks the `TalosUpgrade` `Failed`,
  and stops; the remaining nodes are not touched. The dead node keeps its
  cordon and `outdated` taint — Node objects are not Flux-managed, so both
  persist until removed. Recovery order: power-cycle the node (the installer
  finishes before the reboot, so it boots the target version), uncordon it,
  wait for Ceph `HEALTH_OK`, then annotate the CR with
  `tuppr.home-operations.com/reset="$(date)"`. tuppr re-evaluates, skips
  already-upgraded nodes, clears their taints, and finishes the rollout.
- The cluster runs without failure tolerance meanwhile (etcd 2/3, Ceph
  `min_size` 2 with one OSD down): hold storage changes and anything that
  drains a node until recovery.
- Any HelmRelease whose chart ships a DaemonSet wedges if upgraded during
  the outage: the DaemonSet counts the dead node in its desired set, helm's
  health wait cannot complete, and the release lands in `pending-rollback`
  with Flux retrying. Harmless and self-resolving on node return; merging
  bumps to DaemonSet-shipping charts during a known outage queues them
  behind the wedge.
- Rook probes mon failover (recurring short-lived `mon-canary` pods that
  find no placement and are cleaned up) and refuses `ok-to-stop` while
  redundancy is degraded. Both end on node return, after which deferred OSD
  deployment updates roll one at a time — expected churn, not a fault.
- A drain that evicts the kopiur controller mid-operation produces a burst
  of retried snapshots and UUID-named `snapdel` jobs. The cockpit
  failed-jobs panel counts pod-level retries; judge backup health by
  Snapshot phases, not that panel.
- The descheduler idles with no under-band target available — correct
  behaviour, not a stuck controller.
