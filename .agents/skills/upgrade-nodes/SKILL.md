---
name: upgrade-nodes
description: >-
    Plan and verify Talos or Kubernetes node-version upgrades, including a
    stopped Tuppr rollout. Use for node-version changes; machine-configuration
    edits belong to talos/README.md and physical boot or firmware recovery to
    docs/recovery/node-boot.md.
---

# Upgrade Nodes

Read the shared [node-upgrade procedure](references/node-upgrades.md) before
planning a version change. Resolve the current and target versions from the
owning source and release support information; do not infer them from memory.

Identify the affected upgrade resource, expected order, irreversible changes,
recovery prerequisites and acceptance checks. Present the intended diff and
checks before editing. Distinguish review of a Git change from approval to
merge it or execute a live action; [AGENTS](../../../AGENTS.md) governs both.

Use [maintenance-window](../maintenance-window/SKILL.md) when the plan stops
workloads, recreates volumes or holds imperative state across a merge.
Machine-configuration application follows [Talos](../../../talos/README.md).
A failed rollout follows [failed upgrades](references/node-upgrades.md#failed-upgrades)
before another disruption or retry.

Report actual node/component, scheduling, storage and backup checks, with any
remaining gap. Do not call a successful render a completed rollout.
