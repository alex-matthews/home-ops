# Cluster Model

**When to use:** Flux reconcile path, dependsOn, reconciliation ordering, secrets, ExternalSecret, SOPS, `cluster-secrets`, substitution, backups, Kopiur, PVC, UID/GID, mover identity, RWO, replicas, scheduling, descheduler policy, node placement and rebalancing, rolling Talos upgrades, service networking, LoadBalancer addresses, BGP, L2 announcements, high-risk surfaces.

How a change reaches the cluster, how secrets and state get there, and which
surfaces are high-risk to touch. For repository layout and app file shape see
[`app-pattern.md`](app-pattern.md); for validation commands see
[`validation.md`](validation.md).

## How a merged change reaches the cluster

1. On push to `main`, a GitHub webhook reaches the `github-webhook` `Receiver`,
   which reconciles the `flux-system` `GitRepository` and Kustomization
   immediately. Flux follows `main` through that GitRepository, managed by Flux
   Operator. The configured intervals are drift-correction fallbacks, not the
   normal path — a merged change does not wait for the next poll.
2. `kubernetes/flux/cluster/ks.yaml` defines the `cluster-apps` Kustomization.
   It reconciles `./kubernetes/apps`, enables SOPS decryption, and patches
   every child Kustomization with the same decryption and HelmRelease
   remediation defaults.
3. Each namespace directory's `kustomization.yaml` creates the Namespace, adds
   the shared alerts component (all namespaces) and the SOPS component (only
   namespaces that need `cluster-secrets`), and lists every app `ks.yaml`.
4. Each app `ks.yaml` is a Flux Kustomization that renders the app's `app/`
   directory into the target namespace.

Nothing reaches the cluster except through this path. Imperative changes are
diagnostics-only; Flux overwrites drift on the next reconcile.

## Reconciliation ordering and `dependsOn`

Settled by the #1872 audit (PRs #1877, #1878, #1884–#1888). Re-litigate it
only on new evidence — a controller behaviour change or an actual incident —
never on taste.

The rule, in one sentence: a Kustomization whose product is instances of an
operator's API depends on the Kustomization that ships the operator (a
separate CRD chart sits one rung below its operator); everything else gets
no edge unless it meets the evidence-based exception below. A component's
product means its declared purpose, not whichever resource kind is most
numerous. Supporting defaults:

- No `dependsOn` by default. A runtime dependency does not require a
  reconciliation dependency: PVCs wait for provisioning, pods pend on
  missing devices, and controllers retry. A workload that applies another
  component's CRs incidentally is a consumer, not an instance component,
  and gets no edge — availability edges cost real blocking, as the
  2026-08-28 Ceph maintenance showed for 22 apps (PR #1877).
- Cross-family APIs are present before Flux through one of three bootstrap
  mechanisms: `bootstrap/helmfile/crds.yaml`, a whole-product install in
  the bootstrap apps phase, or platform/machine bootstrap (currently
  `talos.dev`, installed by Talos machine configuration). Flux/Helm keep
  CRD upgrade ownership. Coverage was manually verified at #1887; no
  automated check enforces it.
- Exceptions require demonstrated evidence of a stored-release Helm failure
  with bounded remediation.

The edge table is the graph, not an illustration — change it only with a
recorded reason.

Instance → operator (the component's product is instances of the target's
API; declared intent, kept whether or not bootstrap also installs the
CRDs):

- `rook-ceph-cluster → rook-ceph` — CephCluster and pools; the toolbox
  also needs operator-created inputs (demonstrated).
- `ceph-csi-drivers → rook-ceph` — Driver and OperatorConfig; their CRDs
  and the CSI operator ship in the rook chart.
- `toolhive-config → toolhive-operator` — MCPGroup, VirtualMCPServer.
- `context7-mcp`, `flux-mcp`, `github-mcp`, `grafana-mcp`,
  `konflate-mcp → toolhive-operator` — MCPServer and registry entries.
- `kopiur-repositories → kopiur` — ClusterRepositories.
- `tuppr-upgrades → tuppr` — TalosUpgrade, KubernetesUpgrade.
- `silence-operator-silences → silence-operator` — Silences.
- `actions-runner-controller-runners → actions-runner-controller` —
  AutoscalingRunnerSet.
- `grafana-instance → grafana` — the Grafana CR and datasources.
- `grafana-dashboards → grafana` — dashboards and their folder.
- `flux-instance → flux-operator` — the FluxInstance CR.

Operator → CRD chart:

- `toolhive-operator → toolhive-operator-crds` — the operator exits during
  startup without its CRDs (demonstrated at source).

Exceptions, by evidence:

- `plex → intel-gpu-resource-driver` and
  `drm-exporter → intel-gpu-resource-driver` — DRA resource claims make
  the pods unschedulable without the driver; Helm stores the release,
  times out waiting, and the bounded remediation can stall rather than
  self-heal when the driver appears (source-level demonstration; empirical
  reproduction deliberately waived).

The failure mechanics that make the edge-less default safe, established at
source level on the pinned Flux controllers: a missing CRD in an ordinary
Helm manifest fails before the release is stored and consumes no
remediation, and a failed direct apply requeues at the retry interval —
both self-heal indefinitely, so edge-less consumers converge on their own.
The exception bar is the opposite class: post-storage failure (readiness
waits, hooks, admission during create) consumes bounded remediation and can
stall until a manual reset, and that is what an evidence-based exception
must demonstrate. These facts are version-pinned; re-verify them on major
helm-controller upgrades. Instance edges rest on neither — they are kept
by rule, which is the point of the rule.

The audit's history, accounting, and validation record are in #1872.

## Secrets

Secrets reach workloads through three mechanisms; pick by data shape:

- Ordinary runtime credentials (API keys, passwords, tokens): 1Password →
  onepassword-connect → the `onepassword-connect` `ClusterSecretStore` → a
  per-app `ExternalSecret` → a Kubernetes Secret the workload consumes via
  `envFrom` or `env`. This is the default for anything credential-shaped;
  secret material never appears in Git.
- Build-time substitution for non-credential values: the SOPS component ships
  an age-encrypted `cluster-secrets` Secret into the namespaces that include
  the component — not all do. App `ks.yaml` files opt in with
  `postBuild.substituteFrom: cluster-secrets`, which fills
  `${SECRET_DOMAIN}`-style placeholders when Flux builds the app.
- Exception for indivisible structured files: a config file that mixes
  sensitive and non-sensitive content and cannot cleanly split into
  ExternalSecret fields may be committed as a directly SOPS-encrypted Secret
  in the app directory and mounted as a file (resolute's `secret.sops.yaml`
  household policy is the one current example). Do not use this path for
  ordinary credentials; those belong in 1Password.

## Backups and persistent state

Backup posture is chosen from an app's value and recovery requirements, not
from the presence of a PVC. Protected application state — the norm in the
`default` namespace — gets its PVC from the Kopiur component
(`kubernetes/components/kopiur`), which composes three selectable concerns:
`local` and `remote` snapshot policies, and `restore`, which supplies the
`${APP}` claim on `ceph-block` plus the passive `Restore` that populates it.
Some persistent workloads, notably observability storage, intentionally use
plain PVCs with no backup coverage. Backup topology and restore criteria live
in [`../operations/storage-and-backups.md`](../operations/storage-and-backups.md).

Protected apps run as `runAsUser: 1032` / `runAsGroup: 100` /
`fsGroup: 100`, matching their Kopiur movers and the NAS-side convention;
other apps run whatever identity their image expects. Do not change a
backed-up app's identity without migrating PVC ownership in the same window.

## Replicas and access modes

Stateful apps here are conventionally single-replica (the chart default; most
set no explicit `replicas` or `strategy`). Their `ReadWriteOnce` PVCs bind
read/write mounting to a single node, which constrains scheduling and rolling
updates across nodes — but RWO does not prevent multiple pods on that node
from sharing the volume and is not a single-writer guarantee (Kubernetes has
`ReadWriteOncePod` for that). resolute's stricter rule is application-level:
its SQLite database allows one writer, so it pins `replicas: 1` with
`strategy: Recreate`, routes writes through the one API pod, and must never
be scaled. That constraint comes from the app, not from RWO or any
cluster-wide rule.

## Scheduling and rebalancing

The descheduler's `LowNodeUtilization` strategy uses actual CPU and memory
utilization plus pod count, while the scheduler's `NodeResourcesFit` scoring
uses requested resources. Where it has proven its value so far is convergence
after rolling Talos upgrades. Drains concentrate workloads on the surviving
nodes; once a rebooted node returns, the strategy evicts eligible pods so the
scheduler can repopulate it. The observed post-upgrade burst demonstrated
useful convergence, and similar bursts are expected then. Sustained evictions
outside an upgrade or recovery event may indicate a policy loop. Changes to
descheduler policy should preserve equivalent post-upgrade convergence or
explicitly replace it.

## Service networking

LoadBalancer addresses are advertised to the gateway over BGP only; Cilium's
L2 announcements are disabled. The addresses come from a dedicated range —
the `CiliumLoadBalancerIPPool` in
`kubernetes/apps/kube-system/cilium/app/networking.yaml` — that no node holds
an interface on; the nodes advertise routes to it over their primary link.

The dedicated range is load-bearing, not cosmetic. If service addresses
shared the nodes' subnet, hosts on that segment would ARP for them instead of
routing via the gateway, and with L2 announcements disabled nothing would
answer. Keeping the range free of real interfaces forces every client —
including hosts on the nodes' own VLAN — through the gateway, where routing
and firewall policy are applied, and keeps failover in the routing table
rather than gratuitous ARP. Do not add real interfaces or other devices to
this range, and do not move the pool into a subnet that shares an L2
broadcast domain with the nodes.

## High-risk surfaces

Changing these can break reconciliation, lose data, or silently drop backup
coverage. The prohibitions are in `AGENTS.md`.

- `*.sops.yaml` files: do not reformat or reshape encrypted content.
- `ExternalSecret` names, target secret names, and template keys.
- PVC names, storage classes, access modes, and `dataSourceRef` fields.
- Kopiur repository, policy, schedule, restore, and PVC populator wiring
  (`kubernetes/components/kopiur/` and `kubernetes/apps/kopiur-system/`).
- Backup retention, schedule, copy method, repository secret, and restore
  wiring.
- Rook-Ceph, Cilium, Flux, External Secrets, and cert-manager CRDs.
- Namespace names and app names used by Flux, HelmRelease, alerts, dashboards,
  or backup components.
- Hostnames in manifests, durable docs, rules files, or workflow defaults.
  Prefer manifest substitution such as `${SECRET_DOMAIN}`, or existing repo
  secrets/vars such as `KONFLATE_URL`, instead of hardcoding hostnames. CI,
  workflow logs, generated comments, and status-check links may expose
  configured public hostnames when that is the practical integration shape; do
  not treat that exposure as a blocker by itself.

If a change touches storage or backups, prefer a plan-first pass and include a
restore or rollback validation path.
