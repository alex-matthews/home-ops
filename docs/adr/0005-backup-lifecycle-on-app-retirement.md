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
backups, or delete them, with deletion guarded and keeping free of operator
work. Four designs were tried before this one. Three were rejected by the
owner and an external review recorded on #1986; the fourth was the first
draft of this ADR and was rejected by a second review:

- A fleet-wide delete cascade made keeping expressible only by never
  acknowledging a parked deletion.
- A per-app switch in the retiring app's Kustomization needed two pull
  requests in a fixed order, vanished with the app, and leaned on the
  mass-deletion breaker as an acknowledgement; the breaker is count-based,
  and Kopiur's own retention prunes bypass it.
- A standing retirement ledger of tombstone policies recorded decisions
  durably but added a maintenance surface nobody wanted.
- A recipe that lent ownership back to Kopiur through a temporary policy,
  then deleted the policy so its cascade deleted the snapshots. Adoption is
  a control loop the operator cannot gate; the breaker's acknowledgement is
  repository-scoped and would release deletions that are not this app's; a
  held wave leaves finalizers active until someone acts; and the premise
  that direct kopia use would put credentials on a workstation was false,
  because this repository already injects credentials at run time.

## Decision Drivers

- Keeping backups after removal must need no step and no configuration; it
  is today's behaviour and the safe one.
- Deleting must be a deliberate act with fresh-state guards, one repository
  at a time, never reachable by accident from an ordinary app removal.
- Kopiur's design principle is respected: it deletes only what a live policy
  of its own owns. This decision does not drive Kopiur; it deletes in the
  repository and lets Kopiur observe.
- Repository credentials never rest on a workstation: injected for one
  command and gone with it. No second backup format.
- No standing configuration in every app for an operation that happens a
  few times a year.
- Git stays the source of truth for standing state; a one-off deletion is an
  operator action, like a restore drill, recorded on the issue that
  authorised it.

## Considered Options

| Option                                  | Verdict                                                                                                                                                                                                                  |
| --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Kopia from a workstation, in a recipe   | **Chosen.** Pinned binary, credentials injected per command, the repository's own listing as the guard before and after, one repository at a time. Feasibility proven read-only on 2026-09-05 against both repositories. |
| Kopia by hand                           | **Rejected.** The same two commands without the guards or the record; kept only as what the recipe does, written down.                                                                                                   |
| Fleet-wide delete cascade               | **Rejected.** Keeping becomes never acknowledging a parked deletion, which is control-loop debt, not retention.                                                                                                          |
| Per-app switch, two pull requests       | **Rejected.** Order-dependent across reconciles, lost with the app, and guarded only by a count the breaker may never reach.                                                                                             |
| Retirement ledger of tombstone policies | **Rejected.** Durable, but a standing surface to maintain for a rare operation.                                                                                                                                          |
| A recipe driving Kopiur                 | **Rejected after review.** Adoption cannot be gated, the acknowledgement is repository-wide, a held wave is debt, and its reason to exist was a false premise.                                                           |
| An upstream retirement verb or object   | **Desired, not available.** The door this decision leaves open; see Consequences.                                                                                                                                        |

## Decision

Retirement is two separate acts. Removing an app keeps its backups; nothing
in the component changes and nothing needs deciding at removal time.
Deleting a retired app's backups is one operator recipe:

```sh
just kube retire-backups <app>              # report
just kube retire-backups <app> delete=true  # delete, after a confirmation
```

The recipe runs kopia from the workstation and never drives Kopiur:

1. Refuses unless the app's Flux Kustomization and PVC are gone and no live
   policy resolves to the app's identity. Every read that a guard depends on
   fails closed; the app name is validated as a DNS label and never
   interpolated into shell source.
2. Requires every `ClusterRepository` to be Ready on an S3 backend, reads the
   discovered rows for the identity, groups them by repository, and refuses
   on a repository UID no `ClusterRepository` has or on two usernames for one
   repository. Report mode stops here; it reads only Kubernetes.
3. In delete mode, preflights the one write it makes to the cluster and the
   credential read for each repository, prints the plan, and takes one
   confirmation naming the app and the counts. The confirmation is the
   authorisation; no count-based mechanism stands in for it.
4. One repository at a time: re-runs the guards, re-reads the rows and
   requires them unchanged, connects kopia with credentials injected for that
   command only, requires the repository's listing for the identity to equal
   the rows or aborts with nothing deleted, deletes by source, lists again
   and requires nothing left, then requests a catalog scan and waits for
   Kopiur to honour it so the rows expire. Every step lands in a ledger; on
   any failure the ledger is printed, and nothing claims a rollback.
5. Reports per repository; each repository's next full maintenance reclaims
   the space, and the recipe says so rather than claiming it.

Kopia's config file holds the storage keys while it runs, so the recipe
creates it in a temporary directory removed by an exit trap. The kopia binary
is pinned in the repository's tool set. A grace period is not a mechanism:
keeping needs nothing, and deletion happens when the operator runs the
command. The `maintenance-window` skill governs the run, as it does any
window that deletes data.

The Storage and Backups note documents the two acts, and #1986 records the
first run against resolute as the acceptance case.

## Consequences

- Retiring an app is one pull request; deleting its backups is one recipe
  run later, with no Git dance.
- The repository carries one more operator recipe, about 120 lines, and one
  more pinned tool. The recipe's guards are the review's: fail-closed reads,
  validated input, exact identity and repository matching, the repository's
  own listing before and after, one repository at a time, a ledger on every
  exit.
- Kopiur's breaker is not involved, so there is no held wave and no
  acknowledgement; the price is that once a repository's deletion has run
  there is no rollback. The per-repository order and the ledger are what
  bound a partial run.
- Keeping costs no operator work but still costs repository space; this
  decision accepts that a retired app's history is paid for until someone
  runs the recipe.
- The recipe is a stand-in for a verb Kopiur deliberately lacks. If Kopiur
  gains identity-scoped deletion of discovered snapshots, or a retirement
  object with a deadline, this ADR is superseded and the recipe deleted.
- Two secondary decisions ride along: daily catalog refresh on both
  repositories so rows expire on their own even when no scan is requested,
  and the retired VolSync archive (#2019), which is outside Kopiur and
  decided separately.
- What this does not solve: automatic expiry after a grace period, and a
  durable record of "kept on purpose" beyond the retirement pull request.
  Both are accepted as gaps for a household cluster.
