# AI Workbench

This page is a compact operator note for the Hermes and ToolHive workbench. It
is not a prompt transcript, backlog, or architecture record. The architecture
decision lives in
[`../adr/0001-ai-home-ops-workbench.md`](../adr/0001-ai-home-ops-workbench.md).

Durable decisions belong in ADRs, tasks belong in GitHub, and reusable operating
patterns belong here. Prompt experiments, raw transcripts, and one-off debug
notes should stay out of this file.

## Topology

```text
GitHub Actions
  └─ Renovate PR Review
       └─ Claude Code action

Cluster
  ├─ ToolHive
  │    ├─ Konflate MCP
  │    ├─ GitHub MCP
  │    ├─ Flux MCP
  │    ├─ Grafana MCP
  │    └─ Context7 MCP
  ├─ Hermes
  ├─ litellm-operator
  ├─ LiteLLM, internal-only
  │    ├─ PostgreSQL proxy state, shared cluster
  │    └─ Dragonfly cache/router state
  ├─ future OpenClaw assistant
  ├─ future scheduled triage workers
  └─ future shared memory service

External services
  ├─ GitHub
  ├─ Context7
  ├─ cloud LLM providers
  ├─ Cloudflare API, read-only/scoped if enabled
  └─ 1Password tooling, local/dev-first if enabled
```

## State Boundaries

| State                  | Source of truth                                              |
| ---------------------- | ------------------------------------------------------------ |
| Cluster desired state  | This repository and Flux                                     |
| Backlog                | GitHub Issues, optionally GitHub Projects                    |
| Architecture decisions | ADRs under `docs/adr/`                                       |
| Scratch planning       | Issue drafts                                                 |
| Assistant memory       | Hermes-local or future shared memory, non-authoritative      |
| Secrets                | 1Password, SOPS, External Secrets, and cluster secret stores |

Assistant memory may retain summaries, observations, and references, but it is
not a source of truth. Hermes-local memory is acceptable for proving behaviour;
a shared backend such as Memini can be considered later to avoid tying recall to
a single client. Durable tasks and decisions stay in GitHub and the repo.

## Current Surface

Hermes is the interactive client. It uses the internal LiteLLM gateway by
default and reaches tools through the ToolHive vMCP surface.

LiteLLM runs as a single replica with no public route, backed by the shared
PostgreSQL cluster in the `database` namespace for durable proxy state and by a
non-persistent Dragonfly instance for Redis-compatible cache and router state.
Its UI and API are reachable on the internal Envoy Gateway route; Hermes keeps
using the cluster Service.

The proxy is owned by `litellm-operator`, not by a Helm release: a
`LiteLLMProxy` renders the config and owns the Deployment, Service, ConfigMap,
and HTTPRoute, and one `LiteLLMModel` per model supplies the model list. The
proxy runs in the operator's `file` apply mode, so the rendered `config.yaml`
carries the model list and a model change rolls the Deployment.

The gateway declares `chatgpt/gpt-5.6-luna`, `-terra` and `-sol`, reached through
the ChatGPT subscription rather than an API key. Luna is Hermes's default; the
other two are selectable. Of the 140 providers LiteLLM ships, only `chatgpt` and
`github_copilot` authenticate a subscription, which is why a subscription-only
workbench takes this route and the costs that come with it.

The provider publishes no model list. Check a name with
`codex exec -m <model> --skip-git-repo-check` before declaring it: one that does
not exist registers fine and fails at request time. The LiteLLM UI's health check
returns 400 for these models; that is cosmetic.

Registering a `chatgpt` model before its credentials exist is not inert: the
proxy blocks on a device-code request during startup until the liveness probe
restarts it. Land the token storage and complete the login below before adding
or restoring a `chatgpt` model.

`general_settings.store_model_in_db` is set, so the LiteLLM UI can still add a
model. Such a model is not Git-managed: it exists only in PostgreSQL, and
nothing in this repository recreates it. It is not lost on a rebuild — it is
carried by the PostgreSQL backups described in
[`storage-and-backups.md`](storage-and-backups.md) — but restoring it means
restoring the database, not reconciling Git. Treat a UI-added model as an
experiment and promote anything worth keeping to a `LiteLLMModel`.

The internal route reaches the whole proxy surface, which includes the
unauthenticated `/metrics/` endpoint. Those metrics carry model names and usage
counters, not credentials. Internal routing is not authentication: the UI and
API are protected by the LiteLLM master key, not by the gateway.

### ChatGPT subscription authentication

The `chatgpt` provider authenticates a ChatGPT subscription over an OAuth device
flow rather than an API key. It stores its credentials at
`/app/chatgpt_tokens/auth.json` on the `litellm-chatgpt` PVC, and rewrites that
file whenever it refreshes a token. The file must therefore be writable and must
survive restarts; a read-only Secret mount cannot work, because the proxy would
re-read a permanently stale token and refresh on every request.

That PVC is deliberately node-local (`openebs-hostpath`). Its node affinity keeps
a surge pod on the node already holding the volume, which is what lets the proxy
roll: `LiteLLMProxy` exposes no Deployment strategy, so the workload uses
RollingUpdate where the previous app-template chart defaulted to Recreate.

Do not run the device flow with `kubectl exec` against the Deployment. On a
fresh volume LiteLLM requests a device code during startup, the liveness probe
can restart the pod before the flow finishes, and `exec deploy/litellm` may
select a pod that is already crashlooping. Repeated starts also share the
provider's device-code cooldown.

Run it in a one-off pod instead, with the proxy's pinned image, the same volume,
the same identity, and no probes. This needs the administrative identity,
because creating a pod is a write:

```sh
mise exec -- kubectl --kubeconfig ./kubeconfig apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: litellm-chatgpt-login
  namespace: ai
spec:
  restartPolicy: Never
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
  containers:
    - name: login
      image: ghcr.io/berriai/litellm:v1.101.0@sha256:d295634e09c648dcdb72c4cc2dd226f5fb87823a73e88cbbed6f205e4deb044b
      command:
        - python
        - -u
        - -c
        - "from litellm.llms.chatgpt.authenticator import Authenticator; Authenticator().get_access_token(); print('saved', flush=True)"
      env:
        - name: CHATGPT_TOKEN_DIR
          value: /app/chatgpt_tokens
      volumeMounts:
        - name: chatgpt-tokens
          mountPath: /app/chatgpt_tokens
  volumes:
    - name: chatgpt-tokens
      persistentVolumeClaim:
        claimName: litellm-chatgpt
EOF
```

Follow the verification URL and enter the code printed in its logs, wait for
`saved`, then delete the pod. The identity matters: `_write_auth_file` swallows
its errors, so a file written under the wrong uid makes later refreshes stop
persisting silently rather than failing.

The volume is not backed up. A node-local PV has no CSI snapshots, and the
Kopiur component's snapshot policy targets `ceph-block`. Recovery after losing
the volume is re-running this flow, so a rebuild needs someone present to
complete it.

Hermes pins `_config_version` in its ConfigMap to the schema its image expects.
The config is mounted read-only, so the image's startup migration can never
rewrite it: a mismatch logs a failed migration on every start. Pin the version
deliberately when bumping the image, and read the migration steps in
`hermes_cli/config_migrations.py` for that range first. Do not set
`HERMES_SKIP_CONFIG_MIGRATION` — the failure is the only signal that a bump
needs review.

The Hermes dashboard is exposed through the internal Envoy Gateway route. For
non-loopback binds, Hermes requires a dashboard auth provider; this deployment
uses the bundled username/password provider from `hermes-secret` through the
existing ExternalSecret. Do not restore the obsolete `HERMES_DASHBOARD_INSECURE`
setting for this bind mode.

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

Hermes UI skills are runtime state unless this repo adopts them. Repo-local
skills live under `.agents/skills/<name>/SKILL.md` — `add-app` and
`maintenance-window`. Narrow reusable conventions live in `docs/guides/`.

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
- Repo-owned guidance: committed in `AGENTS.md`, `docs/guides/`,
  `.agents/skills/`, ADRs, or operations docs; useful across clients and
  reviewable like normal repo content.
- Automation-approved: explicitly approved for scheduled or write-adjacent use,
  with durable state, reviewed prompts or skills, and a clear approval boundary.

If a Hermes skill should move out of runtime state, choose the smallest durable
form: a short operations note, a narrow guide under `docs/guides/`, or a new
`.agents/skills/<name>/SKILL.md`.

Before relying on Hermes self-improvement, persist `/opt/data`, keep generated
memory non-authoritative, and review generated skill diffs before reuse. A
shared backend such as Memini should wait until more than one client needs the
same recall surface and the storage/security model is clear.

## Known Hermes Runtime Caveats

If Hermes reports `session terminated (404). need to re-initialize`,
`method "tools/call" is invalid during session initialization`, or
`MCP event loop is not running`, treat that as a Hermes MCP session lifecycle
failure. A ToolHive workload replacement invalidates its in-memory Streamable
HTTP session, but Hermes should detect that on its next keepalive, reconnect,
and repopulate the MCP tools automatically. Wait for the catalog to reappear on
the MCP page, then retry the same single-tool smoke prompt. Reload MCP or restart the
Hermes gateway only if the catalog does not return or the retry still fails
with a session-lifecycle error. Model-provider failures occur before the MCP
call and should be diagnosed separately.

If Hermes shows visible `Thinking` blocks, test the response-display setting
first. Do not reduce `agent.reasoning_effort` just to hide reasoning; that is a
quality knob for tool-heavy operator work.

Hermes Raft platform-plugin warnings about a missing `raft` CLI are upstream
plugin noise in this deployment. Do not install Raft just to silence them. Track
the next Hermes image that includes
[NousResearch/hermes-agent#49240](https://github.com/NousResearch/hermes-agent/pull/49240),
then verify the warning stops after the image update.
