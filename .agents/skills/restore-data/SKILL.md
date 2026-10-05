---
name: restore-data
description: >-
    Plan and verify restoration of existing application-volume or PostgreSQL
    data, including restore drills and data migrations. Use for selecting
    recovery points and proving restored content; initialisation of a
    protected app without a snapshot is outside this workflow.
---

# Restore Existing Data

Establish the affected data, desired recovery point, available repositories
and whether this is an isolated drill, migration or outage recovery. Read
[backup coverage](../../../docs/operations/backups.md#coverage), then the
matching human-readable procedure:

- [Application volumes](references/app-volumes.md) for Kopiur-protected claims.
- [PostgreSQL](references/postgresql.md) for archive/WAL recovery and cutover.

Read only the applicable branch unless the operation crosses both stores.
For a whole-cluster rebuild, start with [bootstrap](../../../bootstrap/README.md)
and follow its links to the data procedures.

Use [maintenance-window](../maintenance-window/SKILL.md) for workload stops,
PVC deletion/recreation or holds across a merge. Before execution, identify
the exact mutations, fresh prerequisites, rollback or recovery limits and
content checks. [AGENTS](../../../AGENTS.md) governs approval; a restore
request does not authorise destructive steps or credential creation.

Stop when a required snapshot, archive, successful state read or compatible
tooling is missing. Do not invent an empty-volume workaround or treat unreadable
data as a pass. Report the selected recovery point, observed content and
consumer acceptance, and any unverified part of the recovery.
