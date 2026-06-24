# ADR-0001: AI Home-Ops Workbench

- **Status:** Accepted, implementation in progress
- **Date:** 2026-06-12
- **Related:** [Issue #1205](https://github.com/alex-matthews/home-ops/issues/1205), [PR #1202](https://github.com/alex-matthews/home-ops/pull/1202)

> Scope: this ADR records the AI workbench architecture and boundaries:
> model/provider routing, MCP, memory/state, community signal intake, and initial
> rollout. It is not the active backlog.

## 1. Context

This repository is the source of truth for a live Talos, Flux, and Kubernetes
home-ops cluster. The operational burden is increasing: dependency updates need
release research, peer repositories are moving quickly, Discord discussions are
hard to retain, and backlog context is too large to hold in working memory.

The immediate trigger is [Issue #1205](https://github.com/alex-matthews/home-ops/issues/1205),
which tracks an AI-assisted review path for Renovate pull requests. That problem
is narrower than the broader workbench, but it is the first concrete
implementation slice.

The desired workbench should help with:

- dependency and release research for Renovate pull requests;
- community trend tracking from peer home-ops repositories;
- backlog, issue, and decision summarisation;
- home-ops and dotfiles coherence while preserving separation of concerns;
- infrastructure and integration questions across GitHub, Kubernetes,
  Cloudflare, observability, and secrets tooling;
- safe drafting of changes, issues, ADRs, and follow-up tasks.

## 2. Constraints

The initial architecture must respect these constraints:

- No local model inference. Current cluster nodes are not sized for local LLMs,
  and there is no dedicated GPU or workstation-class inference node.
- No PostgreSQL dependency. The cluster is not currently suited to run
  CloudNativePG or an equivalent Postgres platform.
- Low operational burden. Components copied from peer repositories must be
  justified against this cluster's constraints rather than adopted wholesale.
- Spend control matters. Cloud inference is acceptable, but provider choice,
  routing, and prompts must avoid uncontrolled API spend.
- Git remains the source of truth. Agents may draft, explain, and recommend, but
  GitHub issues, ADRs, pull requests, and Flux-managed manifests remain the
  durable control plane.
- Discord bot access is not expected to be available. The design must not depend
  on monitoring the Home Operations Discord server directly.

## 3. Decision

Adopt a lightweight AI home-ops workbench in phases.

The current architecture is:

- Pull request review: current implementation uses Claude-backed advisory
  Renovate PR Review. Keep `misospace/pr-reviewer-action`, MiniMax, and
  model-gateway reviewer designs deferred until a separate reviewer decision.
- Agent workbench: use Hermes as the first interactive home-ops workbench.
- MCP gateway: use ToolHive to expose approved read-only MCPs through explicit
  trust boundaries.
- Agent clients: treat Hermes, future OpenClaw, CI reviewers, and scheduled
  triage jobs as clients of the same trusted MCP surface.
- Memory: evaluate Memini or a similar shared backend after the workbench is
  useful.
- Model routing: deploy a small internal LiteLLM MVP for provider aliases,
  metrics, and Redis-backed cache/router coordination.
- Dragonfly: deploy Dragonfly-operator with a non-persistent LiteLLM Dragonfly
  instance; defer durable/shared state until needed.
- Backlog source of truth: use GitHub Issues, optionally GitHub Projects, with
  ADRs for durable architecture decisions.
- Community signal: prefer GitHub-first peer-repo monitoring and sanctioned
  digest exports. Do not use Discord scraping.

The workbench should start read-only wherever possible. Write-capable tools must
be added only after the read-only workflow has proved useful and the approval
boundary is clear.

## 4. Architecture

### 4.1 Component topology

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
  │    ├─ Context7 MCP
  ├─ Hermes
  ├─ future OpenClaw assistant
  ├─ future scheduled triage workers
  ├─ LiteLLM, internal-only MVP
  │    └─ Dragonfly cache/router state
  └─ future shared memory service

External services
  ├─ GitHub
  ├─ Context7
  ├─ cloud LLM providers
  ├─ Cloudflare API, read-only/scoped if enabled
  └─ 1Password tooling, local/dev-first if enabled
```

### 4.2 State and source-of-truth boundaries

| State                  | Source of truth                                               |
| ---------------------- | ------------------------------------------------------------- |
| Cluster desired state  | This repository and Flux.                                     |
| Backlog                | GitHub Issues, optionally GitHub Projects.                    |
| Architecture decisions | ADRs under `docs/adr/`.                                       |
| Scratch planning       | `backlog.md` or issue drafts.                                 |
| Assistant memory       | Hermes-local or future shared memory, non-authoritative.      |
| Secrets                | 1Password, SOPS, External Secrets, and cluster secret stores. |

Assistant memory may retain summaries, observations, and references, but it is
not a source of truth. Hermes-local memory is acceptable for proving behavior; a
shared backend such as Memini can be considered later to avoid tying recall to a
single client. Durable tasks and decisions stay in GitHub and the repo.

### 4.3 Model and provider routing

Provider choices should be workload-driven:

1. Renovate pull request review from real pull requests.
2. Dependency release research with linked changelogs and issue context.
3. Peer-repository digest summarisation.
4. Home-ops operational questions over repo and documentation context.

The current Renovate review lane uses Claude Code as an advisory reviewer
because it produced more useful release research than the initial MiniMax and
`misospace/pr-reviewer-action` attempt. It is not yet a merge gate. MiniMax
remains a deferred option for a future lower-cost or multi-provider reviewer,
especially if routed through LiteLLM.

LiteLLM is useful only if it earns its place as a small gateway:

- stable internal model aliases;
- provider fallback;
- central provider secret handling;
- Prometheus-visible latency, error, and usage metrics;
- cache or budget controls that do not require PostgreSQL.

The initial deployment is an internal-only MVP: one LiteLLM replica, no public
route, no PostgreSQL, and no durable LiteLLM state. Dragonfly is used only as
non-persistent Redis-compatible cache/router state for LiteLLM. Public access,
auth frontends, provider budget enforcement, durable spend tracking, and broader
fallback routing remain separate follow-up decisions. Do not deploy or expand
LiteLLM solely because peer repositories run it.

### 4.4 MCP trust boundaries

MCPs are grouped by risk, not by novelty.

| Tier                       | Examples                         | Initial posture                                 |
| -------------------------- | -------------------------------- | ----------------------------------------------- |
| Public reference           | Context7                         | Allow early; no secrets in queries.             |
| Repository context         | GitHub MCP                       | Start read-only or narrowly scoped.             |
| Rendered GitOps review     | Konflate MCP                     | Read-only; narrow public-route exception below. |
| Observability              | Grafana or metrics MCPs          | Read-only.                                      |
| GitOps health              | Flux MCP                         | Read-only; prefer summary calls first.          |
| Cluster operations         | Kubernetes, Talos                | Defer until RBAC review; read-only first.       |
| Off-cluster infrastructure | Cloudflare, UniFi                | Defer; scoped read-only tokens first.           |
| Secret tooling             | 1Password Developer Environments | Local/dev-first; no whole-vault automation.     |
| Write-capable automation   | Any mutating infra action        | Deferred; require explicit human approval.      |

Context7 reduces stale model knowledge for public documentation. Konflate MCP is
a read-only view over rendered pull request summaries and diffs already exposed
by Konflate, so it is an early source for Renovate and Kubernetes review
evidence. It may reuse the existing Konflate route because it exposes the same
read-only rendered pull request data and does not trigger renders or writes.
Treat pull request text and rendered manifests as untrusted prompt input.

The current ToolHive workbench exposes Context7, GitHub, Konflate, Flux, and
Grafana MCPs to Hermes for evidence gathering and triage. MCP is the reusable
tool boundary: keep useful cluster, repository, and observability capabilities
behind ToolHive instead of hardcoding them into one chat UI. Add an explicit
authentication and approval boundary before exposing private data, fork renders,
mutating tools, or broader agent access.

### 4.5 Agent clients and semi-autonomous operations

Hermes is the current interactive operator workbench: ask questions, pull
evidence, inspect pull requests, and use ToolHive manually. OpenClaw remains a
future candidate for always-on assistant behavior such as channels, multi-agent
routing, scheduled checks, and notifications.

Semi-autonomous operation should start read-only and evidence-first. Useful
early jobs include:

- daily or hourly Flux and Grafana health triage;
- Renovate, release, and pull request research;
- log anomaly summaries;
- misconfiguration scans;
- backup, VolSync, and future Kopiur posture checks;
- issue creation with cited evidence;
- pull request drafts for low-risk repository-only fixes.

The hard boundary is that agents may open issues, pull requests, comments, and
review notes. They must not mutate the live cluster unless the operator
explicitly approves a specific action.

### 4.6 Community signal intake

Discord monitoring is not an initial integration target. Without approved bot
access or a sanctioned export, direct monitoring of Home Operations Discord
channels is not practical and should not be pursued through scraping or user-token
automation.

The preferred intake paths are:

1. Use a sanctioned export of the existing daily digest if one becomes available.
2. Adapt the peer-repository monitoring pattern behind the daily digest, but
   write output into GitHub issues, markdown, or Memini instead of Discord.
3. Manually paste digest content only as a fallback.

The durable capability is community trend intelligence from GitHub activity, not
Discord ingestion itself.

### 4.7 Home-ops and dotfiles boundary

The workbench should understand both `home-ops` and the dotfiles repository, but
it must preserve their different responsibilities:

- `home-ops`: cluster, GitOps, applications, infrastructure integrations, and
  deployment manifests;
- dotfiles: local workstation baseline, shell/editor/agent configuration, and
  local tool ergonomics;
- `mise`: project and local development tool activation where appropriate;
- 1Password: secret and environment contracts.

Agents may recommend coordinated changes across repositories, but each change
should land in the repository that owns the affected concern.

### 4.8 Peer reference posture

Peer repositories are evidence, not target architectures. Use the catalog in
[`../guides/repo-guide.md`](../guides/repo-guide.md) to choose relevant
references by domain, verify their current files before copying a pattern, and
prefer this repo's local conventions when they differ.

Heavy peer choices such as local inference, PostgreSQL, vector databases,
public authenticated MCP routes, agentgateway or MCP federation, SearXNG,
durable memory, shared Dragonfly, or large helper CLIs must be justified by
concrete local consumers before adoption.

## 5. Alternatives Considered

### 5.1 Copy a peer AI stack wholesale

Rejected for the initial rollout. Peer repositories are useful references, but
many run local inference, PostgreSQL-backed state, or broader automation surfaces
than this cluster should adopt now. This specifically includes treating Jory's
multi-cluster, local-inference, and LiteLLM/Postgres-heavy setup as a useful
domain reference rather than a baseline architecture for this cluster.

### 5.2 Local inference first

Rejected for now. The cluster does not have suitable compute or a dedicated GPU.
Local inference can be revisited when hardware changes.

### 5.3 Open WebUI first

Deferred. Open WebUI can be useful as a generic chat UI, but it does not solve
the main workbench problems by itself: repository context, MCP access, backlog
management, and safe operational workflows.

### 5.4 OpenClaw first

Deferred. OpenClaw is promising as the always-on assistant and notification
layer, but it should consume a stable read-only MCP and memory surface rather
than define that surface. Deploy it after Hermes and ToolHive prove useful.

### 5.5 SearXNG first

Deferred. SearXNG does not require PostgreSQL, but it adds operational surface
and often includes Valkey for limiter support. Start with GitHub, Context7, and
provider-native search where available. Add SearXNG only if the workbench needs
a self-hosted metasearch endpoint.

### 5.6 Dragonfly first

Partially adopted. Dragonfly-operator is justified by LiteLLM cache/router
coordination, but the first Dragonfly instance should be non-persistent and
app-local. Durable Redis-compatible state remains deferred until a consumer needs
it. Future consumers may include SearXNG limiter support, shared memory,
assistant state, or broader LiteLLM routing and rate-limit coordination.

### 5.7 Discord bot or Discord scraping

Rejected for now. Bot access is not expected to be available, and user-token or
scraping approaches are not an acceptable design foundation.

## 6. Current Implementation

Implemented:

1. Replace the legacy misospace reviewer with the Claude-backed advisory
   Renovate PR Review workflow.
2. Deploy Hermes as the interactive workbench surface.
3. Deploy ToolHive with read-only Context7, GitHub, Konflate, Flux, and Grafana
   MCP surfaces.
4. Deploy LiteLLM as an internal-only model gateway MVP without PostgreSQL or
   public ingress.
5. Deploy Dragonfly-operator and a non-persistent LiteLLM Dragonfly instance for
   Redis-compatible cache/router state.
6. Route Hermes through the internal LiteLLM gateway as the first model
   consumer.
7. Maintain the compact workbench operator note in
   [`docs/operations/ai-workbench.md`](../operations/ai-workbench.md).

Active rollout tracking belongs in GitHub issues, not in this ADR. Reusable
operating patterns may be summarized in
[`docs/operations/ai-workbench.md`](../operations/ai-workbench.md). Open
decision areas are captured below; update this ADR only when the architecture
decision changes.

## 7. Evaluation Criteria

The initial workbench is successful if it:

- improves Renovate pull request review without excessive noise or cost;
- produces useful summaries of peer-repository activity;
- helps turn vague backlog concerns into GitHub issues or ADR updates;
- answers repo and operations questions with cited, inspectable evidence;
- preserves secret and repository boundaries;
- remains cheap enough and small enough to operate without becoming a new
  platform burden.

It is not successful if it becomes a hidden source of truth, requires broad
write credentials, depends on manual Discord copy-paste for normal value, or
pushes the cluster toward PostgreSQL or local inference before the hardware and
operational model are ready.

## 8. Consequences

### 8.1 Positive

- Creates a concrete starting point for AI-assisted operations without copying a
  heavier peer stack.
- Keeps backlog and decisions in GitHub and the repository instead of agent
  memory.
- Allows PR review work to proceed before the full workbench is deployed.
- Preserves a path to richer automation once read-only workflows prove useful.

### 8.2 Negative / trade-offs

- Cloud inference remains a recurring-cost dependency.
- The first version will be less autonomous than some peer stacks.
- Community trend monitoring will be weaker than full Discord access unless a
  sanctioned digest export is available.
- LiteLLM adds another model gateway surface, so it should stay internal and
  minimal until real consumers justify expansion.
- Dragonfly adds another operator and cluster-scoped RBAC. The first instance is
  intentionally non-persistent cache/router state rather than a durable database.

## 9. Deferred Decision Areas

- Memory: compare Hermes-local persistence with Memini or another shared backend
  after local memory behavior is tested.
- Model routing: decide which additional clients, if any, should use LiteLLM.
- Reviewer lane: decide whether to keep, replace, or gate the current advisory
  Renovate PR Review after another design proves better release research, cost
  control, and re-review behavior.
- Shared state: decide whether Dragonfly should become durable or shared only
  when a concrete consumer needs it.
- OpenClaw: deploy only after the read-only ToolHive and memory boundaries are
  proven useful from Hermes.
- Community signal: prefer sanctioned digest exports or GitHub-first peer repo
  monitoring over Discord scraping.
- Write access: require a separate approval boundary before any MCP can mutate
  GitHub, Flux, Kubernetes, or off-cluster infrastructure.

## 10. References

- [Issue #1205: AI-assisted PR review](https://github.com/alex-matthews/home-ops/issues/1205)
- [PR #1202: docs: add repo guidance for agents](https://github.com/alex-matthews/home-ops/pull/1202)
- [`anthropics/claude-code-action`](https://github.com/anthropics/claude-code-action)
- [`stacklok/toolhive`](https://github.com/stacklok/toolhive)
- [`openclaw/openclaw`](https://github.com/openclaw/openclaw)
- [`dragonflydb/dragonfly-operator`](https://github.com/dragonflydb/dragonfly-operator)
- [`misospace/pr-reviewer-action`](https://github.com/misospace/pr-reviewer-action)
- [`eleboucher/memini`](https://github.com/eleboucher/memini)
- [`onedr0p/home-ops`](https://github.com/onedr0p/home-ops)
- [`buroa/k8s-gitops`](https://github.com/buroa/k8s-gitops)
- [`bjw-s-labs/home-ops`](https://github.com/bjw-s-labs/home-ops)
- [`eleboucher/homelab`](https://github.com/eleboucher/homelab)
- [`m00nwtchr/homelab-cluster`](https://github.com/m00nwtchr/homelab-cluster)
- [`bo0tzz/clusterfuck`](https://github.com/bo0tzz/clusterfuck)
- [`joryirving/home-ops`](https://github.com/joryirving/home-ops)
- [`rcdailey/home-ops`](https://github.com/rcdailey/home-ops)
- [`Tanguille/cluster`](https://github.com/Tanguille/cluster)
- [`jfroy/flatops`](https://github.com/jfroy/flatops)
