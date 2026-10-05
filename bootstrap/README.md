# Bootstrap and Full Rebuild

Verified 2026-10-05 against the repository at `main`; the sequence was not
run.

Use this sequence for a cold start or full rebuild. [Restore-data](../.agents/skills/restore-data/SKILL.md)
links the detailed restore procedures; the [maintenance skill](../.agents/skills/maintenance-window/SKILL.md)
owns durable holds and destructive execution. Read both before planning the
window. Bootstrap renders secrets and writes credential files, so a human
runs those recipes. Read-only inspection remains available to agents.

## Preflight

Any failed prerequisite stops the window:

1. Choose the Git revision, reviewing open PRs that might affect recovery.
   Record nodes, PVCs, addresses, source-verification state and workload/data
   baselines against which recovery will be judged.
2. Confirm the [external dependencies](../ARCHITECTURE.md#layers-and-owners)
   are available, especially the gateway and NAS/Garage. Stop if the gateway
   is degraded or degrades during the window. Arrange administrative access,
   human-supplied bootstrap/decryption inputs, password-manager access and
   console/physical access to every node. Include [workbench login recovery](../docs/operations/workbench.md#login).
3. At GO time, every protected app needs a successful, non-zero snapshot
   younger than 24 hours in **both** repositories. Any missing result stops
   teardown; earlier evidence is not the current gate.
4. PostgreSQL needs a completed base backup younger than 24 hours and a
   reported recovery window. Durably stop every consumer, confirm no client
   connections, switch the final WAL segment and confirm that exact segment
   archived. Freshly exclude surviving old archivers before any successor
   writes to the same archive. [PostgreSQL](../.agents/skills/restore-data/references/postgresql.md)
   defines the recovery and migration checks.
5. Drain every node and confirm no RBD mounts with fresh, successful reads
   on each. The reset wrapper can treat a failed read as no matching mount;
   that is not a safe gate.

These gates protect planned teardown. After failure, preserve the baseline
and inspect surviving volumes, snapshots, PostgreSQL timelines and archivers.
Unavailable state cannot prove fresh destructive preconditions: stop, and
obtain a new approved recovery plan before further resets.

## Execution

Approve the exact reset and disk selection before acting, planning for complete
Ceph data loss. The [reset recipe](../talos/mod.just) selects STATE/EPHEMERAL
labels unless forced; that alone does not establish which physical disks are
erased. Confirm maintenance mode on every node before bootstrap:

```bash
talosctl -n <node> -e <node> version --insecure
```

The human-run `just bootstrap cluster` follows [mod.just](mod.just):

1. Render/apply node configuration; the recognised certificate-required
   response skips an already-configured node.
2. Bootstrap etcd and obtain a direct-node kubeconfig. The etcd loop swallows
   failures until it sees the already-bootstrapped response: a loop is not
   proof of progress. Stop and diagnose unexpected output.
3. Apply base resources, human-resolved bootstrap inputs and [CRDs](helmfile/crds.yaml),
   then install the [core charts](helmfile/apps.yaml), including Flux Operator
   and its instance. Helmfile pulls these pins directly, outside Flux's
   [signature verification](../docs/policy/decisions.md#chart-trust).
4. Write the final kubeconfig, which targets the stable API endpoint. That
   address answers only after Flux reconciles Cilium's networking; until
   then, use a node's direct address as in
   [break-glass access](../docs/recovery/break-glass.md).

Flux then reconciles Kubernetes declarations; machine and external state keep
their own owners. Verify machine changes through [affected-resource readback](../talos/README.md),
not a generic sysctl check. Inspect conditions/events and missing dependencies
or storage before proposing a retry. Failed Kustomization applies retry;
Helm upgrade failures can exhaust the [remediation budget](../kubernetes/flux/cluster/ks.yaml).
Correct the prerequisite first; resets require exact approval. Failed
population follows [claim-specific diagnosis](../.agents/skills/restore-data/references/app-volumes.md#pvc-lifecycle),
never a blanket deletion or hand-population remedy. Stop on failed signature
verification or other unexpected behaviour; do not bypass checks.

## Acceptance

Confirm the intended revision, Ready Kustomizations/HelmReleases, verification
success on configured sources, and restored baseline addresses/resources.
Claims must complete population and their Restore state must agree with
[content evidence](../.agents/skills/restore-data/references/app-volumes.md#verifying-restored-content).
Check PostgreSQL's recovered data, roles/extensions, replication, resumed
archiving and actual consumer recovery; earlier drills held consumers stopped,
so they do not prove unattended recovery. Collect recovery logs promptly while
the observation stack itself rebuilds. A human re-establishes Kubernetes
read-only access by deleting any pre-rebuild `kubeconfig-readonly` in the
main checkout, then running `just kube readonly-token` there with the new
administrative kubeconfig ([access](../docs/operations/access.md)). The
recipe trusts the old file's expiry without asking the cluster, so it would
otherwise keep a token the rebuilt cluster rejects.
