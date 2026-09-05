# ADR-0005: Backup Lifecycle on App Retirement

- **Status:** Proposed
- **Date:** 2026-09-05
- **Related:** [Issue #1986](https://github.com/alex-matthews/home-ops/issues/1986)
  (decision and acceptance case), [ADR-0002](0002-kopiur-backup-storage-shape.md)
  (repository shape)

## Context and Problem Statement

Removing an app from Git prunes its Kopiur policy and schedule. Kopiur keeps
every snapshot the policy made and re-materialises them as `discovered`
rows, forced to `Retain`, that nothing in the cluster can delete. Kopiur
deletes only what a live policy owns, its CLI has no delete verb by design,
and it has no notion of a deadline. Resolute, retired on 2026-09-02, left 41
such snapshots, 31 on the local repository and 10 on the remote.

The owner's requirement is an explicit choice per retirement: keep the
backups, or delete them, with deletion guarded and keeping free. Three
designs were tried before this one and rejected, one by an external
adversarial review whose findings are recorded on #1986:

- A fleet-wide delete cascade made keeping expressible only by never
  acknowledging a parked deletion.
- A per-app switch in the retiring app's Kustomization needed two pull
  requests in a fixed order, vanished with the app, and leaned on the
  mass-deletion breaker as an acknowledgement; the breaker is count-based,
  and Kopiur's own retention prunes bypass it, so an adopting policy with
  retention would have deleted before anyone acknowledged anything.
- A standing retirement ledger of tombstone policies recorded decisions
  durably but added a maintenance surface nobody wanted.

## Decision Drivers

- Keeping backups after removal must cost nothing and need no step; it is
  today's behaviour and the safe one.
- Deleting must be a deliberate act with fresh-state guards, per repository,
  and must never be reachable by accident from an ordinary app removal.
- Kopiur's design principle is respected: it deletes only what a live policy
  of its own owns; nothing bypasses its breaker or its finalizers.
- No repository credentials on a workstation and no second backup tool.
- No standing configuration in every app for an operation that happens a
  few times a year.
- Git stays the source of truth for standing state; a one-off deletion is an
  operator action, like a restore drill, and is recorded on the issue that
  authorised it.

## Considered Options

| Option                                  | Verdict                                                                                                                                                                                                                                |
| --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Kopia directly from a workstation       | **Rejected as the default.** Two commands per repository, but needs the repository credentials and a binary on the workstation, records nothing, and stays manual forever. Kept as the documented fallback when the recipe cannot run. |
| Fleet-wide delete cascade               | **Rejected.** Keeping becomes never acknowledging a parked deletion, which is control-loop debt, not retention.                                                                                                                        |
| Per-app switch, two pull requests       | **Rejected.** Order-dependent across reconciles, lost with the app, and guarded only by a count the breaker may never reach.                                                                                                           |
| Retirement ledger of tombstone policies | **Rejected.** Durable, but a standing surface to maintain for a rare operation.                                                                                                                                                        |
| One-command recipe driving Kopiur       | **Chosen.** A verb Kopiur does not have, implemented as an operator recipe until it does.                                                                                                                                              |
| An upstream retirement verb or object   | **Desired, not available.** The door this decision leaves open; see Consequences.                                                                                                                                                      |

## Decision

Retirement is two separate acts. Removing an app keeps its backups; nothing
in the component changes and nothing needs deciding at removal time.
Deleting a retired app's backups is one operator command:

```sh
just kube retire-backups <app>
```

The recipe drives Kopiur through its own ownership model and refuses to
proceed on any stale precondition:

1. Refuses unless the app's Flux Kustomization is gone and no live policy
   claims the app's identities.
2. Reads the discovered rows for the app's identity on each repository and
   prints the counts, sizes, and newest snapshot; without `delete=true` it
   stops here.
3. Applies, per repository, a throwaway `SnapshotPolicy` with the identity
   pinned, no schedule, no retention block, `defaultDeletionPolicy: Delete`,
   and `onPolicyDelete: Delete`. These objects are not Flux-managed, so no
   reconcile can clear or fight them.
4. Waits until the adopted count equals the discovered count and no
   discovered rows for the identity remain, per repository, then deletes the
   policies. The cascade issues the deletions as external, so the
   mass-deletion breaker applies as a backstop.
5. Prints the acknowledgement command when a repository holds the wave, waits
   for the hold to clear, verifies the delete batch Jobs succeeded and the
   rows are gone, and requests a catalog rescan.
6. Reports per repository; the nightly full maintenance reclaims the space,
   and the recipe says so rather than claiming it.

The retention block is omitted on purpose: retention prunes bypass the
breaker, so a cleanup policy must never prune. Both repositories converge
independently; success on one says nothing about the other. A grace period
is not a mechanism: keeping is free, and deletion happens when the operator
runs the command. The `maintenance-window` skill governs the run, as it does
any window that deletes data.

The Storage and Backups note documents the two acts and the fallback, and
#1986 records the first run against resolute as the acceptance case.

## Consequences

- Retiring an app is one pull request; deleting its backups is one command
  later, with no Git dance and no kopia binary.
- The repository carries one more operator recipe, roughly eighty lines,
  with the review's guards built in: identity enumeration from the rows, no
  retention, both cascades explicit, fresh counts before every destructive
  step, per-repository verification, a rescan after deletion.
- The recipe is a stand-in for a verb Kopiur deliberately lacks. Its
  read-only CLI is a design principle, so an upstream request is unlikely to
  succeed as stated; if Kopiur gains identity-scoped deletion of discovered
  snapshots, or a retirement object with a deadline, this ADR is superseded
  and the recipe deleted.
- Two secondary decisions ride along and are recorded where they land:
  periodic catalog refresh at a daily interval so stale rows expire on their
  own, and the treatment of the retired VolSync archive (#2019), which is
  outside Kopiur and unchanged by this decision.
- What this does not solve: a true automatic expiry after a grace period,
  and a durable record of "kept on purpose" beyond the retirement pull
  request itself. Both are accepted as gaps for a household cluster.
