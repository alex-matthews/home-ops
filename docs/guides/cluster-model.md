# Cluster Model

How a change reaches the cluster, how secrets and state get there, and which
surfaces are high-risk to touch. For repository layout and app file shape see
[`app-pattern.md`](app-pattern.md); for validation commands see
[`validation.md`](validation.md).

## How a merged change reaches the cluster

1. Flux follows `main` through the `flux-system` `GitRepository` managed by
   Flux Operator.
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

## High-risk surfaces

Changing these can break reconciliation, lose data, or silently drop backup
coverage. `AGENTS.md` carries the prohibitions; this is where they live:

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
