# ADR-0001: AI Home-Ops Workbench

- **Status:** Accepted, implementation in progress
- **Date:** 2026-06-12
- **Related:** [Issue #1205](https://github.com/alex-matthews/home-ops/issues/1205), [PR #1202](https://github.com/alex-matthews/home-ops/pull/1202)

> Scope: this ADR covers the home-ops AI workbench architecture, model/provider
> routing, MCP surface, memory and state boundaries, community signal intake, and
> rollout sequence. It deliberately excludes the separate app-builder and local
> developer-velocity stack except where pull request review overlaps.

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

| Area                    | Decision                                                                                                             |
| ----------------------- | -------------------------------------------------------------------------------------------------------------------- |
| Pull request review     | Use Claude-backed Renovate Research Review. Keep `misospace/pr-reviewer-action` and MiniMax deferred for comparison. |
| Agent workbench         | Use Hermes as the first interactive home-ops workbench.                                                              |
| MCP gateway             | Use ToolHive to expose approved read-only MCPs through explicit trust boundaries.                                    |
| Agent clients           | Treat Hermes, future OpenClaw, CI reviewers, and scheduled triage jobs as clients of the same trusted MCP surface.   |
| Memory                  | Evaluate Memini or a similar shared backend after the workbench is useful.                                           |
| Model routing           | Deploy LiteLLM only when multiple consumers, provider aliases, metrics, or fallback routing justify it.              |
| Dragonfly               | Deploy only when real consumers need Redis-compatible cache, session, queue, rate-limit, or memory support.          |
| Backlog source of truth | Use GitHub Issues, optionally GitHub Projects, with ADRs for durable architecture decisions.                         |
| Community signal        | Prefer GitHub-first peer-repo monitoring and sanctioned digest exports. Do not use Discord scraping.                 |

The workbench should start read-only wherever possible. Write-capable tools must
be added only after the read-only workflow has proved useful and the approval
boundary is clear.

## 4. Architecture

### 4.1 Component topology

```text
GitHub Actions
  └─ Renovate Research Review
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
  ├─ future shared memory service
  ├─ future Dragonfly, if shared state consumers justify it
  └─ LiteLLM, if provider routing becomes useful enough

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
| Assistant memory       | Future Memini or shared memory service, non-authoritative.    |
| Secrets                | 1Password, SOPS, External Secrets, and cluster secret stores. |

Assistant memory must not become a hidden backlog, secret store, or decision
database. It may retain summaries, observations, and references that make future
work easier, but any durable task or decision must be written back to GitHub or
the repo.

### 4.3 Model and provider routing

Provider choices should be workload-driven:

1. Renovate pull request review from real pull requests.
2. Dependency release research with linked changelogs and issue context.
3. Peer-repository digest summarisation.
4. Home-ops operational questions over repo and documentation context.

The current Renovate review lane uses Claude Code because it produced more
useful release research than the initial MiniMax and
`misospace/pr-reviewer-action` attempt. MiniMax remains a deferred option for a
future lower-cost or multi-provider reviewer, especially if routed through
LiteLLM.

LiteLLM is useful only if it earns its place as a small gateway:

- stable internal model aliases;
- provider fallback;
- central provider secret handling;
- Prometheus-visible latency, error, and usage metrics;
- cache or budget controls that do not require PostgreSQL.

Do not deploy LiteLLM solely because peer repositories run it.

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

Context7 belongs in the public-reference tier. Its purpose is to reduce stale
model knowledge when reasoning about current documentation. It is not a source
of truth and must not receive sensitive configuration or secrets.

Konflate MCP belongs in the rendered GitOps review tier. It is a read-only view
over the same pull request summaries and rendered diffs Konflate already serves,
so it is a strong early source for AI review of Renovate and Kubernetes changes.
For the Renovate reviewer, it may be enabled on the existing public Konflate
route because that route already exposes the same rendered PR UI and REST data,
and MCP does not trigger renders or forge writes. Add an explicit
ingress/authentication boundary before exposing private repository data, fork
renders, mutating tools, or broader agent access through that route. Treat pull
request text and rendered manifests as untrusted prompt input.

The current ToolHive workbench exposes Context7, GitHub, Konflate, Flux, and
Grafana MCPs to Hermes. These tools should be used for evidence gathering and
triage, not for mutating the cluster or GitHub state. Prompts should avoid broad
inventory calls unless a summary call identifies a concrete problem.

MCP is the tool boundary. ToolHive should make useful cluster, repository, and
observability tools available behind a controlled interface that any capable
agent client can consume. This keeps the useful work behind the MCP surface
instead of hardcoding it into one chat UI. Hermes can use that surface now;
OpenClaw, a CI reviewer, or scheduled triage jobs can use the same surface later.

### 4.5 Agent clients and semi-autonomous operations

Hermes is the current interactive operator workbench: ask questions, pull
evidence, inspect pull requests, and use ToolHive manually. OpenClaw is a better
fit for the always-on personal assistant layer: channels, multi-agent routing,
skills, cron or webhook automation, and notifications.

The intended shape is not Hermes versus OpenClaw. Both should consume the same
trusted ToolHive vMCP, the same model gateway if LiteLLM is deployed, and
eventually the same non-authoritative memory backend.

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

## 5. Alternatives Considered

### 5.1 Copy a peer AI stack wholesale

Rejected for the initial rollout. Peer repositories are useful references, but
many run local inference, PostgreSQL-backed state, or broader automation surfaces
than this cluster should adopt now.

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

Deferred. Dragonfly-operator is a reasonable substrate if the workbench grows
toward the bjw-s-labs shape, where several AI-adjacent workloads use
Redis-compatible backing. It should not be deployed only because it is useful in
theory. It becomes justified when real consumers need cache, session, queue,
rate-limit, or shared-memory backing, such as SearXNG limiter support,
Memini/shared memory, LiteLLM cache or coordination, or OpenClaw/Hermes state.

### 5.7 Discord bot or Discord scraping

Rejected for now. Bot access is not expected to be available, and user-token or
scraping approaches are not an acceptable design foundation.

## 6. Rollout Plan

Implemented:

1. Replace the legacy misospace reviewer with the Claude-backed Renovate
   Research Review workflow.
2. Deploy Hermes as the interactive workbench surface.
3. Deploy ToolHive with read-only Context7, GitHub, Konflate, Flux, and Grafana
   MCP surfaces.
4. Capture starter Hermes prompts in
   [`docs/operations/ai-workbench.md`](../operations/ai-workbench.md).

Next:

1. Stabilize ToolHive MCP surfaces and prompt examples through actual use.
2. Continue hardening Renovate Research Review for usefulness, cost control, and
   predictable re-review behavior.
3. Evaluate shared assistant memory, likely Memini or a similar backend, and
   design retrieval and reranking deliberately.
4. Add Dragonfly when the first real consumer needs Redis-compatible backing.
5. Revisit LiteLLM once multiple model consumers or routing/metrics needs exist.
6. Deploy OpenClaw as an always-on assistant only after the read-only MCP and
   memory stack is sane.
7. Add peer-repository trend summarisation through GitHub-first ingestion.
8. Revisit OpenCode, Open WebUI, SearXNG, local inference, and write-capable MCPs
   only after the read-only workbench remains useful.

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
- LiteLLM may not be worth its operational cost until there are multiple model
  consumers.
- Dragonfly adds another operator and stateful substrate, so it should wait for
  concrete consumers.

## 9. Deferred / Open Questions

1. Which shared memory backend should Hermes and future agents use, and is a
   reranker required from day one?
2. Should LiteLLM be deployed before there is a second active model consumer?
3. Should `misospace/pr-reviewer-action` be revisited behind LiteLLM, or should
   the Claude-backed Renovate Research Review remain the primary reviewer?
4. Which first consumer, if any, justifies Dragonfly-operator?
5. What is the minimum safe OpenClaw deployment shape for read-only triage and
   notifications?
6. Can the existing daily home-ops digest be exposed through a sanctioned
   machine-readable feed?
7. Which MCPs should be allowed write access, if any, and what approval boundary
   is required?
8. Should the app-builder/developer-velocity workbench receive a separate ADR?

## 10. References

- [Issue #1205: AI-assisted PR review](https://github.com/alex-matthews/home-ops/issues/1205)
- [PR #1202: docs: add repo guidance for agents](https://github.com/alex-matthews/home-ops/pull/1202)
- [`anthropics/claude-code-action`](https://github.com/anthropics/claude-code-action)
- [`stacklok/toolhive`](https://github.com/stacklok/toolhive)
- [`openclaw/openclaw`](https://github.com/openclaw/openclaw)
- [`dragonflydb/dragonfly-operator`](https://github.com/dragonflydb/dragonfly-operator)
- [`misospace/pr-reviewer-action`](https://github.com/misospace/pr-reviewer-action)
- [`eleboucher/memini`](https://github.com/eleboucher/memini)
- [`eleboucher/homelab`](https://github.com/eleboucher/homelab)
- [`bjw-s-labs/home-ops`](https://github.com/bjw-s-labs/home-ops)
- [`joryirving/home-ops`](https://github.com/joryirving/home-ops)
- [`Tanguille/cluster`](https://github.com/Tanguille/cluster)
- [`jfroy/flatops`](https://github.com/jfroy/flatops)
