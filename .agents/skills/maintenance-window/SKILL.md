---
name: maintenance-window
description: Planning and execution workflow for live maintenance windows in this GitOps cluster — control-loop timeline, durable-hold analysis, and guarded destructive steps. Use whenever a change needs workloads stopped, PVCs deleted or recreated, or any imperative cluster state held across a merge.
---

# Maintenance Windows

Plan live maintenance around the controllers that continue reconciling
while workloads are stopped. Correct manifests alone do not preserve an
imperative hold across the next apply.

## The invariant

**An imperative hold is a lease, not a lock.**

A controller can overwrite an imperative change to a field it manages.
Identify the owning Git field, the controller and the next apply that can
clear each hold, including one triggered by your own merge. Suspending a
child does not help if its parent can reapply that suspension field.

A full teardown and rebuild is the largest window of all; its sequence,
guards, and the handover checks are in
`bootstrap/README.md`. Read it before planning one.

## Before the window: build the control-loop timeline

Required artifact. One row per step, no vague entries:

| #   | What the operator does | What Flux does at its next reconcile | What survives it |
| --- | ---------------------- | ------------------------------------ | ---------------- |

Rules for filling it in:

- Derive each answer from field ownership and the acting controllers, not
  intent. Name the next reconcile or apply that can clear each hold.
- A hold that must outlive a merge belongs **in the merge commit**, not in a
  `kubectl` call. Carry it in Git, or suspend the controller.
- Where an operator must stop, plan a durable hold on that operator as well
  as its resources. Analyse the parent Kustomization, HelmRelease and
  Deployment before choosing suspension or scale-to-zero; another controller
  can undo an unprotected hold. Each mutation needs its own approval.
- Name every controller that acts on the target objects, not just the
  workloads that mount them. Suspending an app's Kustomization does not stop
  Kopiur or any other operator from acting on live CRs.
- Mirror every stop with an explicit restart and verification step. Check
  whether Git owns the replica field; resuming a HelmRelease alone is not
  proof that a manually stopped workload will return.
- Note which guardrails are expected to trip (for example Tuppr blocking
  upgrades during a restore) so they are not misread as failures.

## During the window: guard every destructive step

Destructive steps require **fresh, successful state reads**. Stop on a
failed or missing read; an empty result is not proof that a precondition
holds. Compare restore points and mounting workloads with this window's
recorded baseline immediately before each destructive action.

Every guard must fail closed: failed reads, missing evidence or a mismatch
with the approved baseline stop the destructive action. Include the actual
expected restore points and zero mounting workloads in the window plan; do
not copy a count from a previous window.

Also during execution:

- Capture restore points **before** the destructive step and verify them
  (count, non-zero content), rather than trusting that a backup ran.
- Check the reclaim policy before deleting a PVC. `Delete` can destroy the
  underlying volume; verify recovery before authorising that deletion.
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
- Treating a successful render as complete evidence without checking its
  base, changed objects and missing-input warnings; follow
  `CONTRIBUTING.md#validate-locally`.
- Asserting a shape is schema-valid from field names alone without checking
  `required`; CRD admission is not exercised by a Kustomize render.
