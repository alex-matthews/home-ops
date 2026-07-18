---
name: audit-findings
description: Findings-first audit workflow for infrastructure, network, and configuration reviews — read-only evidence gathering, classified findings, and separately approved change proposals with validation and rollback. Use for audit- or evaluation-shaped issues such as firewall reviews, Talos config modernization, or storage evaluations.
---

# Findings-First Audit

Workflow for audit-shaped work (for example #1534 UniFi firewall audit, #1530
Talos config review, #1488 storage evaluation): produce a findings report
first; propose mutations separately, each with validation and rollback. Never
mix evidence gathering with changes.

## Ground rules

- Evidence gathering is strictly read-only. The AGENTS.md diagnostics boundary
  applies: `get`, `describe`, `logs`, `events`, `diff`, dry-runs, and the
  equivalent `flux`/`helm`/`talosctl`/appliance-API read calls. Anything that
  changes live state needs explicit user approval of the exact action, after
  the findings report.
- Keep detailed topology, addresses, identifiers, and credential handling out
  of public prose (issues, PRs, committed docs). Summarise in neutral terms;
  keep raw detail in local scratch files or private notes.
- Distinguish confirmed observations from hypotheses. An unverified hypothesis
  stays labelled as one — do not let it harden into a finding without
  evidence.
- Compare against peer or upstream patterns where useful (repo-guide reference
  catalog), but treat them as comparison inputs, not targets.

## Workflow

1. **Scope.** Restate the audit scope from the driving issue: what is in
   scope, what is explicitly out, and what "done" looks like. List the
   evidence sources you intend to use (repo manifests, live read-only
   commands, appliance APIs or UIs, peer repos, upstream docs).
2. **Gather evidence.** Work through the scope area by area. For each piece of
   evidence, record the command or source and where the output lives, so the
   audit is reproducible.
3. **Classify findings.** Every observation lands in exactly one bucket:
    - **Confirmed problem** — evidence shows a real defect or risk.
    - **Optional optimisation** — works today; a change would improve it.
    - **Leave unchanged** — reviewed and correct; record _why_ it should stay,
      so the next audit does not relitigate it.
4. **Propose changes separately.** For each proposed mutation: the exact
   change, the validation plan (how we will know it worked), the rollback
   plan (how we get back), and the blast radius if it goes wrong. No broad
   permits or convenience widenings bundled in.
5. **Deliver.** Write the findings report where the driving issue directs
   (issue comment, docs/operations note). Proposed mutations are approved and
   executed one at a time, never as a batch.
