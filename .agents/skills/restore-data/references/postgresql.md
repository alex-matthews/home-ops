# Restore PostgreSQL

Verified 2026-10-05 against the repository at `main`; not against a live
restore.

[Policy](../../../../docs/policy/decisions.md#postgresql) owns the
shared-cluster and durability choices; [access](../../../../docs/operations/access.md)
covers the identities. Use
[maintenance-window](../../maintenance-window/SKILL.md) for consumer holds
or other disruption; select an isolated drill, migration or full rebuild
before acting.

The [cluster manifests](../../../../kubernetes/apps/database/postgres/app) declare
Barman base backups, WAL archiving and recovery. Only archived data is
recoverable; retention or a healthy replica is not an unlimited guarantee.
An empty archive blocks this recovery path. Two simultaneous archivers must
never write the same destination. A read-only drill may consume the source
archive; same-archive rebuild requires an exclusive successor and the intended
history.

## Admission and drills

Admit consumers or start migrations only with a healthy archive/recovery
window and a demonstrated second-cluster WAL replay. For an approved drill:

1. Write a marker after the base backup and confirm its WAL segment archived.
2. Recover an isolated cluster with compatible PostgreSQL/extension images
   and libraries. Omit top-level WAL-archiver `plugins`, retaining the
   external-source plugin; the drill must not write to the source archive.
3. Check available extensions (`pg_available_extensions`) and restored
   per-database versions (`pg_extension`), health, marker, databases and roles;
   record
   selected backup/timeline and recovery window. Remove only drill resources
   under the approved cleanup plan.

Earlier PostgreSQL drills read R2 under the versions their record names (the
retired `storage-and-backups.md`, listed in the [retired
documents](../../../../docs/README.md#retired-documents)). Each new window
needs fresh evidence; those drills do not certify today's consumers.

## Migration

A migration also requires durable consumer holds, fresh zero-client-connection
checks and confirmation that the exact final switched WAL segment archived.
Exclude old writers, recover the replacement with a distinct archive, then
verify recovered data/roles/extensions, replication and resumed archiving.
Cut consumers over through authorised configuration changes and prove their
operation before deleting the old cluster. Credential changes remain human-only.

[Bootstrap](../../../../bootstrap/README.md) owns the full-rebuild preflight
and same-archive successor sequence.

## Upgrades

Extension libraries in an image and installed database extension versions
must agree; update each Database declaration deliberately after compatible
libraries are available. Current Renovate rules hold the PostgreSQL major;
a major migration needs coordinated PostgreSQL/extension images, library
paths and declarations. An image bump alone does not migrate database
extensions. Follow [migration](#migration) for admission, consumer holds,
archive ownership and verified cutover.
