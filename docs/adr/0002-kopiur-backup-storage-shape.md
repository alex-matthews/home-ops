# ADR-0002: Kopiur Local Backend and Remote Shape

- **Status:** Accepted
- **Date:** 2026-07-20
- **Related:** [Issue #1487](https://github.com/alex-matthews/home-ops/issues/1487)

## Context and Problem Statement

The Kopiur pilot (bazarr, NFS export on the NAS) proved the snapshot,
maintenance, and restore mechanism end-to-end. Two storage decisions remained
open: the production local backend (inline NFS versus an S3 service), and the
off-site shape (`RepositoryReplication` to R2 versus an independent R2
repository).

A 20 GiB synthetic-load test (2026-07-20) supplied the missing evidence:

- Backup wrote at ~165 MB/s and never disturbed anything.
- Restore read at ~63 MB/s and made the NAS **NFS service** stop answering new
  TCP connections; the `nfs_probe` health check failed and the zeroscaler HPAs
  scaled every NAS-dependent app (including Plex) to zero mid-restore,
  recovering 30 seconds later.
- Incremental snapshots and compression behaved as expected (5 s mover for a
  68 MB change; compressible data collapsed in the repository).

The casualty was the NFS daemon's connection handling under Kopiur's read
load — not disk bandwidth. Community experience adds that
`RepositoryReplication` cannot filter snapshots, so a replicated remote
inherits the local cadence and retention wholesale.

## Decision Drivers

- The `nfs_probe` → zeroscaler guardrail is deliberate hang-mount protection
  and stays as-is; backups must not trip it.
- The NAS has a single storage volume; no separate pool or disks exist.
- Remote cadence and retention should be settable independently of local.
- Off-site copies should not share a corruption domain with the local
  repository.
- Low operational burden; prefer shapes proven in peer repositories.

## Considered Options

1. **Local: inline NFS** (pilot shape) — rejected. Kopiur traffic shares the
   NFS daemon with every runtime app mount; restore-scale reads knock the
   daemon over and the guardrail takes all NAS apps down.
2. **Local: S3 on cluster storage** — rejected. Backups would share the
   Rook-Ceph failure domain with the data they protect.
3. **Local: S3 served by Garage on the NAS** — chosen. Moves backup IO onto a
   separate daemon so the NFS service no longer carries it; spindle contention
   remains but was harmless in both test directions. No new volume is needed —
   the isolation that matters is service-level, not disk-level. A peer
   repository runs Kopiur against an S3 endpoint on its NAS host the same way
   ([ClusterRepository](https://www.github.com/onedr0p/home-ops/blob/main/kubernetes/apps/kopiur-system/kopiur/repository/clusterrepository.yaml)).
4. **Remote: `RepositoryReplication` to R2** — rejected. Couples remote
   cadence/retention to local, propagates local repository damage, and its
   seed/sync reads the local repository — on NFS, the exact read pattern that
   tripped the guardrail.
5. **Remote: independent R2 repository** — chosen. Own cadence, retention,
   password, and maintenance; reads the CSI-staged clone (never the NAS); an
   independent corruption domain. Costs a second snapshot job and maintenance
   lifecycle per app, which is nvme-side and acceptable.

## Decision

- The production local backend is **S3 served by Garage running on the NAS**,
  with data in a shared folder on the existing volume.
- The off-site shape is an **independent R2 repository** with its own schedule
  and retention. `RepositoryReplication` is not used.

## Consequences

- The zeroscaler trip mechanism observed in the pilot is defused for both the
  local path (different daemon) and the R2 path (NAS not involved).
- Garage is a NAS-side service outside GitOps: its setup and upgrade path must
  be documented in the NAS runbook, and it becomes a dependency of the backup
  (not restore-from-R2) path.
- The pilot's `RepositoryReplication` gates in the storage document are
  superseded; the restore-from-R2 proof moves to the first production app's
  acceptance criteria.
- The pilot repository migrates to the S3 backend during production rollout;
  the NFS pilot export is retired afterwards.
