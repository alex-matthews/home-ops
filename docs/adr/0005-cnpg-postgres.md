# ADR-0005: Shared PostgreSQL on CloudNativePG

- **Status:** Proposed
- **Date:** 2026-09-16
- **Related:** [ADR-0002](0002-kopiur-backup-storage-shape.md), the
  shared-memory review of 2026-09-15 (private notes)

## Context and Problem Statement

Four candidate workloads need PostgreSQL, and none has it: LiteLLM runs
without a database, so its key management, spend tracking and stored
configuration are off; Immich and kguardian both ship a bundled single-pod
database whose backup is best-effort or absent; the shared memory store
selected on 2026-09-15 runs on SQLite for its experiment and would move to
PostgreSQL only if adopted. Two of them need the VectorChord extension. The
cluster has no PostgreSQL, no second backup system, and a doctrine that
every new operator, CRD family and backup path is an ask-first change with
its rationale recorded.

## Decision Drivers

- One database service for several small consumers, each isolated by role
  and database, rather than one bundled database per application.
- A backup path that is not Kopiur, because Kopiur restores PVCs and a
  PostgreSQL restore must replay WAL to a point in time.
- Storage that does not stack PostgreSQL replication on Ceph replication.
- The cluster's three nodes are all control-plane nodes whose system SSDs
  also carry etcd; write wear and fsync contention are the constraints to
  watch.
- Peer patterns from the catalogue, so the shape is one the community
  already runs and Renovate already tracks.

## Considered Options

1. **CloudNativePG, two instances, asynchronous replication, local SSD
   class, Barman Cloud plugin to R2.** Chosen.
2. CloudNativePG with a single instance. Smaller, but node loss means a
   restore from the archive, losing whatever the archive had not yet
   received, and it forfeits the reason the local SSD class was chosen over
   Ceph.
3. CloudNativePG with three instances. A third copy of every write on a
   third system SSD, for a quorum nothing planned needs, and the third
   node is the one whose storage is due for replacement.
4. Per-application bundled databases. No shared operations, no tested
   backup, and the extension problem solved separately each time.
5. CloudNativePG on `ceph-block`. Snapshots for free, but PostgreSQL
   replication on top of Ceph's own replication multiplies every write
   across the NVMe OSDs.

## Decision

Run the CloudNativePG operator 1.30.0 (chart 0.29.0) in `cnpg-system`
beside the Barman Cloud plugin 0.15.0 (chart 0.8.0), both charts verified
against their signing workflow. Run one `Cluster` named `postgres` in
`database` with two instances on `openebs-hostpath`, pinned to m2 and m3
with required anti-affinity, on the PostgreSQL 18 standard image with the
VectorChord and pgvector extension images declared in the spec so a
restored cluster carries them.

Back up through the plugin only: continuous WAL archiving and a daily base
backup to an R2 bucket of its own, 14 days of retention, under the archive
name `postgres-v1`. The local Garage store plays no part; the shared-memory
review left its role open and nothing here needs it. Kopiur does not
protect the cluster's PVCs.

Consumers get a `DatabaseRole` and a `Database` in the `database`
namespace, with the role's password in a `kubernetes.io/basic-auth` Secret
carrying the `cnpg.io/reload` label, and connect through the `postgres-rw`
service. The first consumer is LiteLLM. No consumer depends on the cluster
until a restore from R2 into a second cluster has been demonstrated.

One shared cluster is the default, not a rule. A consumer whose PostgreSQL
major or extension version must diverge from the shared cluster's gets its
own `Cluster` under the same operator, with its own archive name. Peers who
run Immich apart did so because it once needed the custom
`cloudnative-vectorchord` image; extension images remove that need.

## Consequences

- Two new CRD families (`postgresql.cnpg.io`, `barmancloud.cnpg.io`) and a
  second backup system, each recorded here as the doctrine requires. The
  operator adds ten CRDs and two admission webhooks.
- The `postgres` Kustomization depends on both operator Kustomizations,
  under the instance-of-an-operator's-API rule in the cluster model.
- Replication is asynchronous: a failover can lose transactions the
  primary had acknowledged but not yet streamed. The recovery point of a
  restore from R2 is the last WAL segment the archive received, so archive
  health bounds data loss and is checked before any consumer is admitted.
- Restore is proven by bootstrapping a second `Cluster` from the archive
  under a different name, checking that a marker written after the last
  base backup is present and that both extensions load, and deleting it;
  the recipe and its pass criteria are in the storage note. No consumer is
  admitted before that has been done once. Reusing an archive name for
  two live clusters corrupts the archive.
- The local SSD class still uses the kubelet bind-mount path that #2057
  moves. The move is a bootstrap of a replacement cluster from the archive
  onto the new path, with writers quiesced and consumers cut over, as the
  storage note describes; it shares its mechanism with the restore drill
  but is not one. #2057 does not block this decision.
- Revisit the instance count if a consumer needs synchronous durability,
  or if a failover is observed to lose data a consumer could not
  tolerate. Scaling to one is a spec change; scaling to three needs the
  affinity widened to m1 or relaxed, since the pair is pinned to m2 and
  m3.
- Revisit the storage class if measured system-SSD wear or etcd fsync
  latency on m2 or m3 becomes unacceptable; the alternative is
  `ceph-block`, option 5, with the write amplification it carries.
- The operator's stated Kubernetes support stops at 1.36 while this
  cluster runs 1.37; peers run the same pairing. A demonstrated
  incompatibility is handled by holding the operator at its current
  version and raising it upstream; if the operator cannot run on the
  cluster's Kubernetes at all, this decision is revisited.
- The PostgreSQL image and the two extension images are pinned by digest
  in the `Cluster` spec, which Renovate does not track today; bumps are
  manual until a rule is added.
- System-SSD write wear on m2 and m3 becomes a tracked metric against the
  drives' 300 TBW rating. Wear figures are scenarios until measured.
