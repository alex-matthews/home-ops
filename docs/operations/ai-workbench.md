# AI Workbench

This page is a compact operator note for the Hermes and ToolHive workbench. It
is not a prompt transcript, backlog, or architecture record. The architecture
decision lives in
[`../adr/0001-ai-home-ops-workbench.md`](../adr/0001-ai-home-ops-workbench.md).

Durable decisions belong in ADRs, tasks belong in GitHub, and reusable operating
patterns belong here. Prompt experiments, raw transcripts, and one-off debug
notes should stay out of this file.

## Current Surface

Hermes is the interactive client. It uses the internal LiteLLM gateway by
default and reaches tools through the ToolHive vMCP surface.

Current ToolHive tools:

- Context7 for public documentation lookup.
- GitHub and Konflate for repository and pull request evidence.
- Flux for GitOps health.
- Grafana for Prometheus, Alertmanager, and VictoriaLogs-backed observability.

Hermes runtime state under `/opt/data` is currently `emptyDir`. Generated
skills, memory, cron state, and sessions are disposable until that volume is
deliberately made persistent.

## Boundaries

- Keep the workbench read-only unless a separate approval boundary exists.
- Do not expose ToolHive, Hermes, or MCP routes externally without a separate
  authentication decision.
- Do not paste secrets into prompts. Refer to configured secrets, repository
  variables, or manifest substitutions by name.
- Prefer summary tools first, then drill into a bounded workload only when the
  summary shows a signal.
- Visible scratch reasoning is a Hermes runtime/display issue, not something to
  solve by lowering reasoning quality.

## First Useful Loop

Use Hermes first for read-only cluster health work. PR review is secondary here
because this repo already has a dedicated review workflow.

The first useful loop is manual cluster-health triage:

1. Flux summary health: failing or suspended Kustomizations and HelmReleases.
2. Grafana datasource reachability.
3. Prometheus firing alerts.
4. Prometheus anomaly signals such as recent restarts, waiting reasons, failed
   jobs, non-running pods, and PVC phase changes.
5. VictoriaLogs queries only when a metric, alert, or Flux result points at a
   bounded namespace, pod, or workload.

The useful behavior is judgment over evidence, not following a rigid script. A
good run should name what changed, what is probably benign, what still needs
evidence, and what deserves attention now.

Promote this loop only after it is useful manually. The next step is a
local-delivery Hermes cron pilot with a self-contained prompt and read-only
ToolHive tools. It should write or display a short report locally first; add
notifications only after the local output is consistently useful.

Do not start with a broad log anomaly hunter. Use VictoriaLogs as a drill-down
source after metrics, alerts, or Flux identify a bounded namespace, pod, or
workload.

## Grafana And VictoriaLogs

Grafana provisions the VictoriaLogs datasource through the Grafana Operator in
`kubernetes/apps/observability/grafana/instance/grafanadatasource.yaml`.

After Flux reconciles, verify `grafana_list_datasources` shows a
VictoriaLogs-compatible datasource, expected as `victoria-logs`.

Recommended post-reconcile smoke path:

1. `grafana_list_datasources`
2. `grafana_list_loki_label_names` for the VictoriaLogs datasource
3. `grafana_query_loki_logs` with a narrow selector and short time window

The Grafana MCP log tools keep Loki-compatible names even when the datasource is
VictoriaLogs.

Do not use generic Grafana API request tools for routine workbench triage. Do
not modify dashboards, alerts, routing, or datasources from Hermes.

## Automation Candidate

The first cron or watcher should be boring and read-only:

- Inputs: Flux summary, Grafana datasource status, firing alerts, bounded
  Prometheus anomaly queries, and VictoriaLogs only for scoped symptoms.
- Output: one short operator report with "benign", "needs attention", and
  "evidence missing" sections.
- Delivery: local Hermes output first, then a notification channel only after
  repeated useful runs.
- Non-goals: no cluster writes, no GitHub issue creation, no dashboard edits, no
  broad log scraping, and no external routes.

Promotion criteria:

1. Two manual runs produce concise, accurate reports.
2. Two local cron runs produce the same quality without manual prompt repair.
3. Runtime state is persistent enough that skills, memory, and cron config
   survive pod replacement.
4. The output is better than existing Alertmanager and Grafana notifications,
   either because it correlates evidence or because it suppresses known-benign
   noise with clear reasons.

## Hermes Skills And Memory

Hermes UI skills are runtime state unless this repo adopts them. Codex also
supports repo-local skills under `.agents/skills/<name>/SKILL.md`, but this repo
has not adopted that convention yet. The only committed agent-specific directory
today is `.agents/instructions/` for narrow reusable instructions.

Before relying on generated skills, confirm this guardrail posture in the
Hermes config:

- `skills.write_approval: true`: generated skill writes are staged for review.
- `skills.guard_agent_created: false`: the scanner is a heuristic tripwire and
  is noisy for ops/security-flavored runbooks.
- `curator.consolidate: false`: background LLM skill-library refactors are off.

Use these states when evaluating a Hermes-generated skill:

- Runtime draft: exists only under Hermes `/opt/data/skills`; useful for manual
  testing, not durable behavior.
- Reviewed runtime skill: manually inspected in Hermes and acceptable for
  interactive use; still not a repo source of truth.
- Repo-owned guidance: committed in `AGENTS.md`, `.agents/instructions/`,
  `.agents/skills/`, ADRs, or operations docs; useful across clients and
  reviewable like normal repo content.
- Automation-approved: explicitly approved for scheduled or write-adjacent use,
  with durable state, reviewed prompts or skills, and a clear approval boundary.

If a Hermes skill should move out of runtime state, choose the smallest durable
form: a short operations note, a narrow `.agents/instructions/` file, or a
first `.agents/skills/<name>/SKILL.md` that establishes the repo skill
convention.

Before relying on Hermes self-improvement, persist `/opt/data`, keep generated
memory non-authoritative, and review generated skill diffs before reuse. A
shared backend such as Memini should wait until more than one client needs the
same recall surface and the storage/security model is clear.

## Known Hermes Runtime Caveats

If Hermes reports `session terminated (404). need to re-initialize`,
`method "tools/call" is invalid during session initialization`, or
`MCP event loop is not running`, treat that as a Hermes MCP session lifecycle
failure. Reload MCP or restart the Hermes gateway before retrying the same
single-tool smoke prompt.

If Hermes shows visible `Thinking` blocks, test the response-display setting
first. Do not reduce `agent.reasoning_effort` just to hide reasoning; that is a
quality knob for tool-heavy operator work.

Hermes Raft platform-plugin warnings about a missing `raft` CLI are upstream
plugin noise in this deployment. Do not install Raft just to silence them. Track
the next Hermes image that includes
[NousResearch/hermes-agent#49240](https://github.com/NousResearch/hermes-agent/pull/49240),
then verify the warning stops after the image update.
