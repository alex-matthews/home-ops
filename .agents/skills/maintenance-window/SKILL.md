---
name: maintenance-window
description: Planning and execution workflow for live maintenance windows in this GitOps cluster — control-loop timeline, durable-hold analysis, and guarded destructive steps. Use whenever a change needs workloads stopped, PVCs deleted or recreated, or any imperative cluster state held across a merge.
---

# Maintenance Windows

Workflow for windows that mutate live state (for example the 2026-07-25 Kopiur
PVC-population cutover). The manifests being correct is not the hard part.
The hard part is that Flux is reconciling _while you work_, and it does not
know you are mid-window.

## The invariant

**Git is the only durable state. Every imperative change is a lease, not a
lock.**

Anything set with `kubectl patch`, `scale`, `suspend`, or `annotate` on a
Flux-managed object survives exactly until the next successful apply of the
Kustomization that owns it. During a window the apply that clears your holds
is usually the one you triggered yourself — merging the change, or deleting
the object whose invalid spec was making the dry-run fail.

Knowing this is not enough. It has been written down, correctly, by an agent
who then relied on an imperative hold an hour later. Use the timeline below
so the question is forced rather than remembered.

## Before the window: build the control-loop timeline

Required artifact. One row per step, no vague entries:

| #   | What the operator does | What Flux does at its next reconcile | What survives it |
| --- | ---------------------- | ------------------------------------ | ---------------- |

Rules for filling it in:

- Column three is answered from column two, not from intent. If Flux
  re-applies the owning Kustomization, every field not in Git is gone —
  say so explicitly, per step.
- A hold that must outlive a merge belongs **in the merge commit**, not in a
  `kubectl` call. Carry it in Git, or suspend the controller.
- Prefer controller-level suspension to per-object suppression. Per-object
  flags (`spec.paused`, `spec.schedule.suspend`, `spec.suspend`) are cleared
  by the next apply; a suspended controller is not. Suspend the operator's own
  Kustomization and HelmRelease and scale its Deployment to zero.
- Name every controller that acts on the target objects, not just the
  workloads that mount them. Suspending an app's Kustomization does not stop
  Kopiur or any other operator from acting on live CRs.
- Stop and start steps must mirror each other explicitly. Most charts here
  pin no `replicas`, so un-suspending a HelmRelease does not undo a manual
  scale-to-zero; the window must scale back up by hand.
- Note which guardrails are expected to trip (for example Tuppr blocking
  upgrades during a restore) so they are not misread as failures.

## During the window: guard every destructive step

Destructive steps are gated on **freshly re-read state**, never on state
asserted earlier in the window. Re-read, assert, and refuse rather than
proceed on a stale precondition.

Write the guard so it fails closed:

```sh
# assert preconditions immediately before the destructive action;
# exit non-zero and change nothing if any fails
[ "$RESTORE_POINTS" = "19" ] && [ "$MOUNTING_PODS" = "0" ] && ... || exit 1
```

This is the control that has actually caught a real problem in this repo: a
pre-deletion guard found that a merge had silently cleared 19 Kustomization
suspends, and refused to delete. Keep it even when the state "cannot" have
changed — that belief is the failure mode it exists to catch.

Also during execution:

- Capture restore points **before** the destructive step and verify them
  (count, non-zero content), rather than trusting that a backup ran.
- Check the reclaim policy before deleting a PVC. `Delete` means the
  underlying volume goes with it and recovery is from backup only.
- Stop and report rather than improvise. A failed restore, an unexpected
  controller action, or a guard trip needs a decision, not a workaround.
- Prefer one long-running watch to repeated polling, and report actual state
  rather than narrating expectations.

## After the window

- Validate against a recorded baseline: file counts and ownership compared to
  the pre-window snapshot stats, not just "the app started".
- Distinguish verified from assumed in the write-up. If a check could not be
  run, say which and why.
- Record what the control loop did that the plan did not predict. That is the
  reusable output of the window; the successful steps are not.

## Anti-patterns

- Treating a `kubectl`-applied hold as durable across a merge.
- Suppressing individual CRs when the actor is a controller.
- Reviewing the diff and the sequence, but never modelling the reconciler as
  a participant in the window.
- Using local render tooling as branch-diff evidence when it resolves child
  Kustomization content from the pinned remote ref (see the validation notes
  in `docs/guides/repo-guide.md`).
- Asserting a shape is schema-valid from field names alone without checking
  `required`; CRD admission is not exercised by a Kustomize render.
