# Standing Decisions

A register: each `##` entry is one decision, opens with the date it was
decided (or last verified, where it is doctrine), and is linked by its anchor.
Changing these standing choices, exceptions, deferrals or rejections requires
an approved PR with reasons and explicit supersession. [Retired
records](../README.md#retired-documents) remain history;
[AGENTS](../../AGENTS.md) owns change control. Exposure decisions are in
[public surfaces](public-surfaces.md).

## Chart trust

Decided 2026-08-07.

Cosign verification on eligible OCIRepositories authenticates chart bytes to
a signer, not content safety, workload images, provenance or tag immutability.
Mutable tags remain mutable, and Sigstore can become an update dependency.
[Bootstrap](../../bootstrap/README.md) pulls charts directly through Helmfile,
outside source-controller verification.

Validate the pinned artifact cryptographically before adopting an identity.
Observe its repository, workflow and ref; anchor issuer/subject regexes and
use strict version-ref patterns. Inspect reusable-workflow reachability and
untrusted triggers. Keyless verification requires `matchOIDCIdentity`;
unconstrained identities and organisation-wide subjects are rejected. Keyed
verification needs a validated pinned key and support in the signature check.
Establish acceptance on the deployed verifier, not the CLI alone. Prove a
verification change elsewhere before extending it to bootstrap-critical Flux.

Five classes distinguish what is trusted:

| Class                        | Meaning and accepted limitation                                                                                                                   |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| Direct upstream workflow     | Maintainer-triggered publisher workflow; certificate binds repository, workflow and ref.                                                          |
| Reusable-workflow custody    | Certificate binds the called workflow; Flux cannot constrain its caller. Registry write access and workflow custody remain the accepted boundary. |
| Mirror custody               | Reusable-workflow custody plus repackaging; this proves mirror publication, not upstream authorship.                                              |
| Signed, verifier unsupported | The deployed verifier cannot accept the signature; track verifier/publisher changes rather than imply successful verification.                    |
| Unsigned or unverifiable     | Explicit exclusion, without any claim that exclusion is safe.                                                                                     |

Changing identities or removing/loosening verification, including by removing
an app, requires fresh evidence, reasons and the `verify/declared` label.
Never loosen trust to clear failure.

## Chart exclusions and coverage

Decided 2026-08-07.

Excluded manifests declare `unsigned` (no material found), `keyed-unpinned`
(keyed material exists but no trusted key adopted), `verifier-gap` (known
verifier limitation), or `unverifiable` (investigation found no usable chart
signature). A publisher that stops signing needs an explicit exclusion. The
exclusion inventory is not maintained here: the
[inventory script](../../.github/scripts/chart-signing-inventory.sh) derives
it from the manifests.

The [coverage script](../../.github/scripts/chart-signing-coverage.sh),
run by the required Coverage job of
[Chart Verify](../../.github/workflows/chart-verify.yaml), enforces the rule:
each OCIRepository is the sole YAML document in its `ocirepository.yaml`, with
a unique name/URL pair and exactly one verify block or exclusion, and it
guards the [trust changes](#chart-trust) that need `verify/declared`; an
exclusion does not bypass this. Coverage proves declarations, not their
truth.

On a failure, inspect verification/readiness conditions, artifact, revision
and generation. A failed verification prevents replacement; a missing
artifact can have other causes, so infer no history from absence alone
([checked controller](https://redirect.github.com/fluxcd/source-controller/blob/456fa323ef6a4b977f220cf2c60298bf193497ba/internal/controller/ocirepository_controller.go)).
Diagnose before a reviewed identity correction or revert. Recheck the
deployed verifier when Flux changes.

The intended failure boundary is a frozen chart update with an existing
healthy release preserved. If verification discards a stored artifact,
degrades a release or blocks unrelated reconciliation, stop extending the
policy and investigate. Image admission, digest inventories and provenance
layers need separate decisions; this mechanism adds no operator, CRD or
admission surface.

## Reconciliation ordering

Decided 2026-09-04.

The [ordering decision](https://github.com/alex-matthews/home-ops/issues/1872)
sets the rule: a Kustomization whose product is instances of an operator's
API depends on the Kustomization that ships the operator (and an operator
whose CRDs ship in a separate CRD chart depends on that chart); everything
else gets no edge unless it meets the evidence-based exception, which requires
demonstrated evidence of a stored-release Helm failure with bounded
remediation. Runtime dependencies and incidental custom-resource use get no
edge by default: availability edges block unrelated spec changes during an
outage. Change an established edge only with new controller/incident
evidence and a reason.

Direct custom resources can retry until the API appears. A Helm exception must
show failure after release history is recorded, exhausting the [parent
remediation budget](../../kubernetes/flux/cluster/ks.yaml). Check effective
controller images and failure paths before changing an exception; chart pins
alone do not establish controller versions. A manual retry/reset remains a
live mutation requiring approval. The [edge table](#dependency-edges) is the
resulting graph.

## Dependency edges

Verified 2026-10-05 against the repository at `main`.

This table is the graph under the [ordering rule](#reconciliation-ordering),
kept by hand for now. It is a candidate for generation from the `ks.yaml`
files; until then, check it against them when an edge changes.

| Edge                                                                                        | Reason                                                                                                                                                 |
| ------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `rook-ceph-cluster → rook-ceph`                                                             | Instance: CephCluster and pools                                                                                                                        |
| `ceph-csi-drivers → rook-ceph`                                                              | Instance: Driver and OperatorConfig, shipped in the rook chart                                                                                         |
| `toolhive-config → toolhive-operator`                                                       | Instance: MCPGroup, VirtualMCPServer                                                                                                                   |
| `context7-mcp`, `flux-mcp`, `github-mcp`, `grafana-mcp`, `konflate-mcp → toolhive-operator` | Instance: MCPServer and registry entries                                                                                                               |
| `litellm → litellm-operator`                                                                | Instance: LiteLLMProxy and LiteLLMModel                                                                                                                |
| `kopiur-repositories → kopiur`                                                              | Instance: ClusterRepositories                                                                                                                          |
| `tuppr-upgrades → tuppr`                                                                    | Instance: TalosUpgrade, KubernetesUpgrade                                                                                                              |
| `silence-operator-silences → silence-operator`                                              | Instance: Silences                                                                                                                                     |
| `actions-runner-controller-runners → actions-runner-controller`                             | Instance: AutoscalingRunnerSet                                                                                                                         |
| `grafana-instance`, `grafana-dashboards → grafana`                                          | Instance: the Grafana CR, datasources, dashboards and folder                                                                                           |
| `flux-instance → flux-operator`                                                             | Instance: the FluxInstance CR                                                                                                                          |
| `postgres → cloudnative-pg`, `plugin-barman-cloud`                                          | Instance: the shared CNPG `Cluster` and its Barman `ObjectStore`                                                                                       |
| `kritika-postgres → cloudnative-pg`                                                         | Instance: kritika's own CNPG `Cluster`                                                                                                                 |
| `toolhive-operator → toolhive-operator-crds`                                                | Operator → CRD chart: the operator exits at startup without its CRDs                                                                                   |
| `plex`, `drm-exporter → intel-gpu-resource-driver`                                          | Exception: unschedulable DRA consumers can exhaust the remediation budget                                                                              |
| `kopiur-repositories → rook-ceph-cluster`                                                   | Exception: a population deadline failure can become terminal for the claiming PVC UID ([#1983](https://github.com/alex-matthews/home-ops/issues/1983)) |

## CRD upgrades

Verified 2026-10-05 against the repository at `main`.

Bootstrap supplies some APIs before Flux runs: the
[CRD Helmfile](../../bootstrap/helmfile/crds.yaml) applies CRDs extracted from
upstream charts, and the [core charts](../../bootstrap/helmfile/apps.yaml) are
installed by Helmfile. That coverage is maintained by hand, so for a chart
upgrade that touches those APIs, inspect its templates, hooks and rendered
changes; release notes alone are insufficient. The
[parent patch](../../kubernetes/flux/cluster/ks.yaml) sets
`crds: CreateReplace` on install and upgrade for every nested HelmRelease;
leaf files and Helm defaults do not establish the effective policy.

## Secrets and substitution

Verified 2026-10-05 against the repository at `main`.

Use External Secrets for ordinary credentials and SOPS for domain-style
substitution. An indivisible structured file mixing sensitive and ordinary
content may instead be an app-local SOPS Secret mounted as a file. This
exception grants no permission to create or edit credential material.

## Data protection

Decided 2026-07-20.

Keep two independently written repositories: Garage S3 outside Ceph and
off-site R2. Backup traffic must stay off NFS; this avoids NFS-daemon coupling,
not shared NAS disks. A replication-only third copy needs its own repository
and recorded decision.

Observability history and Hermes runtime state are intentionally unprotected.
New persistence or coverage needs a design decision; a PVC alone is not
grounds to add backups. [Backups](../operations/backups.md) explains how to
establish which claims are protected.

## PostgreSQL

Decided 2026-09-16.

The shared cluster is the default for small compatible consumers, each with
its own database and role. Incompatible major/extension requirements justify
separate clusters and archives. Node-local storage avoids double replication
but shares system SSDs with etcd; retain SSD-health, write-latency and
etcd-fsync monitoring; revisit the storage class if measured SSD wear or etcd
fsync latency becomes unacceptable. Asynchronous failover can lose
acknowledged writes. Revisit replication/durability policy when loss
tolerance changes; more replicas alone do not make it synchronous. Expanding
beyond current placement requires wider node eligibility while preserving
required pod anti-affinity.

Declared CNPG 1.30 on Kubernetes 1.37 is
[tested but unsupported](https://cloudnative-pg.io/docs/1.30/supported_releases/)
(checked 2026-10-04). The risk remains accepted: hold the operator version on
incompatibility, seek an approved upstream report, and revisit the choice if
CNPG cannot run.

Before admitting a consumer, satisfy the [archive and drill
prerequisites](../../.agents/skills/restore-data/references/postgresql.md#admission-and-drills).

## kritika database exception

Decided 2026-10-04.

kritika runs its own `Cluster`, `kritika-postgres`, in the
`kritika` namespace, with one instance on `openebs-hostpath` pinned to m1, no
backup and no PodDisruptionBudget. Its history is accepted as losable for a
trial of four to eight weeks: reviews and findings remain on GitHub. A
separate cluster can be upgraded or reset on its own while kritika promises
no schema upgrade path. Revisit at the end of the trial, when kritika ships
supported migrations, or if that history becomes worth keeping. A second
instance would use synchronous replication with `dataDurability: preferred`.

## Renovate review

Decided 2026-10-06.

kritika reviews Renovate pull requests. The Renovate PR Review workflow, a
Claude Code reviewer in GitHub Actions that ran beside kritika on Renovate
pull requests under `kubernetes/` as a bridge, is retired with its prompt
([#2325](https://github.com/alex-matthews/home-ops/issues/2325)).

Two independent counts listed what mattered to an operator in each pull
request, from its render and upstream sources, then scored each review
against that list. On 2026-10-05, over five pull requests reviewed before
kritika's [Renovate rule](../../.kritika/renovate.md) asked for operator
notes, the Claude reviewer stated 16 of 29 points correctly, 3 imprecisely
and missed 10, with 5 false claims; kritika stated 7, 2 imprecisely and
missed 20, with none. On 2026-10-06, over the next five both reviewed with
that rule in place, kritika stated 11 of 14 correctly, 2 imprecisely and
missed 1, with no false claim; the Claude reviewer stated 3, 4 imprecisely
and missed 7, with one. Five of its seven misses were after-merge checks its
prompt excluded; without them the scores were 3, 4 and 2 against kritika's
6, 2 and 1. It caught nothing that mattered which kritika missed.

The second batch had no hard case: no database operator roll, migration,
single-instance store, diverged release tags or re-review, the classes where
kritika missed most in the first count. Its coverage of those is untested.
Revisit if kritika misses something that matters on a database, CRD or
node-upgrade update.

## Workbench and automation

Decided 2026-06-12.

Additional clients, provider routes, mutating tools, automation and external
exposure need a concrete purpose, authentication and spend assessment, and
explicit approval. Treat external content and repository text as untrusted
prompt input; never include secrets. Cloud models avoid a local generative
stack without suitable hardware; the existing CPU embedding service is a
different workload. Heavier peer designs still need a local consumer and
resource justification. Dragonfly remains an app-local, disposable cache.
Direct Discord monitoring/scraping and whole-vault secret automation remain
excluded.

The workbench should produce cited evidence at low noise and cost. It must
not become a hidden source of truth or depend on broad write access. Internal
routing does not establish authentication: verify each dashboard and tool
boundary independently before expanding it.

Before promotion, require two useful manual runs, then two useful local
scheduled runs without prompt repair, enough durable state to survive pod
replacement, and a demonstrated benefit beyond existing notifications.
Scheduling needs approval; useful local output precedes separately approved
notifications. None of these gates grants cluster writes, issue publication,
dashboard edits or public exposure.

Review generated skills before reuse. A reviewed runtime skill is still not
repository guidance: promote it to the smallest appropriate durable home.
Keep Hermes's skill write approval (`skills.write_approval`) on and its
curator consolidation (`curator.consolidate`) off; do not weaken them to make
promotion easier.

## Appliance certificates

Verified 2026-10-05 against the repository at `main`.

The router and NAS use independent local DNS-01 issuance for their LAN
management interfaces, avoiding a shared ingress key and cluster-dependent
renewal. This is externally managed state, not a Git guarantee; credential
and certificate operations are human-only.

## Bypass merges

Verified 2026-10-05 against the repository at `main`.

Only missing cluster-hosted reporting during an outage permits consideration
of a bypass, never a real failed check. Obtain exact approval, run matching
[local checks](../../CONTRIBUTING.md#validate-locally), including Flate and
image diff, record commands/results and reason, then observe Render and Flux
at the merged revision. Include workflow checks for workflow/Renovate
changes. A low-risk docs-only direct-main change is a separate exceptional
approval, with formatting and a recorded reason; changed operational
instructions still need verification.
