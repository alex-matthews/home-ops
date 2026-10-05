# Restore Application Volumes

Verified 2026-10-05 against the repository at `main`; not against a live
restore.

Use this procedure for existing protected data. [Backups](../../../../docs/operations/backups.md)
establishes coverage and current repository evidence; [access](../../../../docs/operations/access.md)
covers the identities. Record the intended snapshot and
pre-window data baseline before acting. Use
[maintenance-window](../../maintenance-window/SKILL.md) for disruptive steps.

## UID/GID and mover permissions

Keep app ownership, mover identity and NAS mapping distinct. Set mover
identity explicitly so restoration does not depend on a running pod.
Repository mover defaults and operation overrides are separate from policy
identity. Before admission or identity changes,
verify numeric ownership and modes. Migrate ownership in the same authorised
window and prove application reads/writes afterwards; `fsGroup` does not
repair server-side NFS ownership.

## PVC lifecycle

App/PVC renames, component rewiring and substitution changes are migrations.
Verify recent local **and** remote snapshots before merging them. Flux can
prune claims, and Delete reclaim can destroy the underlying volume; deletion
requires separate approval under [maintenance](../../maintenance-window/SKILL.md).
Model every acting controller: suspending Flux does not stop Kopiur, and a
parent can undo a child hold.

A protected claim without a local snapshot fails closed instead of receiving
an empty volume. Stop for a human decision; this guide supplies no fresh-volume
workaround. In the inspected Kopiur 0.10.11 path, terminal population failure
belongs to the claiming PVC UID, not necessarily every sibling claim.
Inspect binding, reason and resolved snapshot. Recreating a Restore cannot
repopulate a bound claim; re-resolution may select different data. Preserve
partial data; claimant recreation needs an approved maintenance plan.

## Verifying restored content

Compare the pre-window snapshot name/time/size, the repository's snapshot and
the Restore's resolved ID. Require completed population, recorded file
counts/ownership and application-data checks; successful status alone is
insufficient. Compare the first post-restore snapshot, allowing explained
normal churn. A smaller `du` may reflect overlay mounts or SQLite WAL
checkpointing; investigate rather than presume success or loss.

Check SQLite integrity on an isolated writable clone with tooling compatible
with the application's build, not against live writers. Unreadable data is
not a passing result. Render success cannot substitute for these checks.
