# Node Upgrades

How Talos and Kubernetes version bumps roll through the nodes, what a healthy
rollout looks like, and which side effects are expected rather than incidents.
Baseline observations are from the 2026-08-06 Talos 1.13.7 → 1.13.8 rollout.

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
recovery window, and the Renovate group PR pre-pulls changed images through
Image Pull before merge, so the reboot window does not include image download
time.

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
(`kubernetes/apps/kube-system/descheduler/`) is what restores balance: it
compares actual usage from metrics against per-dimension thresholds and
evicts up to five pods per node per five-minute cycle from overutilized
nodes. In this cluster CPU and memory sit far below the 50% targets, so the
pod-count dimension (target 45% of pod capacity) is what actually drives
rebalancing after a rollout.

Convergence is deliberately gradual — expect balance within a few cycles, not
immediately. Verify with pods-per-node counts rather than assuming:

```sh
kubectl get pods -A -o wide --field-selector=status.phase=Running
```

Balanced per the stated thresholds does not mean numerically equal: the
descheduler stops evicting once no node exceeds the target thresholds, so a
residual skew inside the target band is the policy working, not failing.
