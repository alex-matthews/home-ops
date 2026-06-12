# ADR-0001: AI Home-Ops Workbench

- **Status:** Proposed
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

The initial architecture is:

| Area | Decision |
| --- | --- |
| Pull request review | Start with `misospace/pr-reviewer-action` for advisory Renovate review. |
| Agent workbench | Use Hermes as the first interactive home-ops workbench to evaluate. |
| MCP gateway | Use ToolHive to expose approved MCPs through explicit trust boundaries. |
| Memory | Evaluate Memini for assistant memory and context recall, not as backlog source of truth. |
| Model routing | Evaluate MiniMax first as the non-OpenAI cloud inference provider. Use OpenAI API only where quality justifies spend. |
| LiteLLM | Treat as a thin gateway candidate for aliases, metrics, fallbacks, and provider isolation. Do not rely on Postgres-backed LiteLLM features initially. |
| Backlog source of truth | Use GitHub Issues, optionally GitHub Projects, with ADRs for durable architecture decisions. |
| Community signal | Prefer GitHub-first peer-repo monitoring and sanctioned digest exports. Do not use Discord scraping or user-token automation. |

The workbench should start read-only wherever possible. Write-capable tools must
be added only after the read-only workflow has proved useful and the approval
boundary is clear.

## 4. Architecture

### 4.1 Component topology

```text
GitHub Actions
  └─ misospace/pr-reviewer-action
       └─ cloud inference provider or LiteLLM alias

Cluster
  ├─ ToolHive
  │    ├─ GitHub MCP
  │    ├─ Context7 MCP
  │    ├─ observability MCPs
  │    └─ future read-only infra MCPs
  ├─ Hermes
  ├─ Memini
  └─ LiteLLM, if provider routing becomes useful enough

External services
  ├─ GitHub
  ├─ Context7
  ├─ cloud LLM providers
  ├─ Cloudflare API, read-only/scoped if enabled
  └─ 1Password tooling, local/dev-first if enabled
```

### 4.2 State and source-of-truth boundaries

| State | Source of truth |
| --- | --- |
| Cluster desired state | This repository and Flux. |
| Backlog | GitHub Issues, optionally GitHub Projects. |
| Architecture decisions | ADRs under `docs/adr/`. |
| Scratch planning | `backlog.md` or issue drafts. |
| Assistant memory | Memini, non-authoritative. |
| Secrets | 1Password, SOPS, External Secrets, and cluster secret stores. |

Memini must not become a hidden backlog, secret store, or decision database. It
may retain summaries, observations, and references that make future work easier,
but any durable task or decision must be written back to GitHub or the repo.

### 4.3 Model and provider routing

The first provider evaluation should be workload-driven:

1. Renovate pull request review from real pull requests.
2. Dependency release research with linked changelogs and issue context.
3. Peer-repository digest summarisation.
4. Home-ops operational questions over repo and documentation context.

MiniMax should be evaluated first because it may provide a more cost-effective
cloud inference lane than additional OpenAI API usage. OpenAI remains the quality
fallback for harder work if the cost is justified. Anthropic/Claude Code remains
a later fallback if a subscription is available and the workflow can use
subscription-backed automation rather than direct API spend.

LiteLLM is useful only if it earns its place as a small gateway:

- stable internal model aliases;
- provider fallback;
- central provider secret handling;
- Prometheus-visible latency, error, and usage metrics;
- cache or budget controls that do not require PostgreSQL.

Do not deploy LiteLLM solely because peer repositories run it.

### 4.4 MCP trust boundaries

MCPs are grouped by risk, not by novelty.

| Tier | Examples | Initial posture |
| --- | --- | --- |
| Public reference | Context7 | Allow early; no secrets in queries. |
| Repository context | GitHub MCP | Start read-only or narrowly scoped. |
| Observability | Grafana or metrics MCPs | Read-only. |
| Cluster operations | Kubernetes, Flux, Talos | Defer until RBAC review; read-only first. |
| Off-cluster infrastructure | Cloudflare, UniFi | Defer; scoped read-only tokens first. |
| Secret tooling | 1Password Developer Environments | Local/dev-first; no whole-vault automation. |
| Write-capable automation | Any mutating infra action | Deferred; require explicit human approval. |

Context7 belongs in the public-reference tier. Its purpose is to reduce stale
model knowledge when reasoning about current documentation. It is not a source
of truth and must not receive sensitive configuration or secrets.

### 4.5 Community signal intake

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

### 4.6 Home-ops and dotfiles boundary

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

Deferred. OpenClaw may be useful later if Hermes is too limited, but the initial
surface should be smaller and easier to reason about.

### 5.5 SearXNG first

Deferred. SearXNG does not require PostgreSQL, but it adds operational surface
and often includes Valkey for limiter support. Start with GitHub, Context7, and
provider-native search where available. Add SearXNG only if the workbench needs
a self-hosted metasearch endpoint.

### 5.6 Discord bot or Discord scraping

Rejected for now. Bot access is not expected to be available, and user-token or
scraping approaches are not an acceptable design foundation.

## 6. Rollout Plan

1. Implement [Issue #1205](https://github.com/alex-matthews/home-ops/issues/1205)
   with `misospace/pr-reviewer-action` in advisory-only Renovate review mode.
2. Run a small provider evaluation for MiniMax against real home-ops workloads.
3. Land repository guidance for agents, including [PR #1202](https://github.com/alex-matthews/home-ops/pull/1202)
   or an equivalent structure.
4. Deploy ToolHive with a minimal read-only MCP set, starting with GitHub and
   Context7.
5. Evaluate whether LiteLLM is needed before multiple consumers exist. If
   deployed, use it only as a thin gateway at first.
6. Deploy Memini and Hermes for interactive home-ops assistance.
7. Add peer-repository trend summarisation through GitHub-first ingestion.
8. Add observability and off-cluster MCPs only after trust boundaries and tokens
   are scoped.
9. Revisit OpenClaw, OpenCode, Open WebUI, SearXNG, and local inference after the
   minimal workbench has proved useful.

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

## 9. Deferred / Open Questions

1. Which MiniMax model and pricing tier is appropriate for Renovate review and
   digest summarisation?
2. Should `misospace/pr-reviewer-action` call a provider directly first, or go
   through LiteLLM from day one?
3. Can the existing daily home-ops digest be exposed through a sanctioned
   machine-readable feed?
4. Which MCPs should be allowed write access, if any, and what approval boundary
   is required?
5. Should the app-builder/developer-velocity workbench receive a separate ADR?

## 10. References

- [Issue #1205: AI-assisted PR review](https://github.com/alex-matthews/home-ops/issues/1205)
- [PR #1202: docs: add repo guidance for agents](https://github.com/alex-matthews/home-ops/pull/1202)
- [`misospace/pr-reviewer-action`](https://github.com/misospace/pr-reviewer-action)
- [`eleboucher/memini`](https://github.com/eleboucher/memini)
- [`eleboucher/homelab`](https://github.com/eleboucher/homelab)
- [`joryirving/home-ops`](https://github.com/joryirving/home-ops)
- [`Tanguille/cluster`](https://github.com/Tanguille/cluster)
- [`jfroy/flatops`](https://github.com/jfroy/flatops)
