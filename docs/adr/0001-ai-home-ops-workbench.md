# ADR-0001: AI Home-Ops Workbench

- **Status:** Accepted
- **Date:** 2026-06-12
- **Related:** [Issue #1205](https://github.com/alex-matthews/home-ops/issues/1205), [PR #1202](https://github.com/alex-matthews/home-ops/pull/1202)

This ADR records the decision and its boundaries. The deployed surface, its
operating patterns, and its runtime caveats are in
[`../operations/ai-workbench.md`](../operations/ai-workbench.md).

## Context and Problem Statement

This repository is the source of truth for a live Talos, Flux, and Kubernetes
home-ops cluster. The operational burden is increasing: dependency updates need
release research, peer repositories move quickly, Discord discussions are hard
to retain, and backlog context is too large to hold in working memory.

The immediate trigger was
[Issue #1205](https://github.com/alex-matthews/home-ops/issues/1205), an
AI-assisted review path for Renovate pull requests — narrower than the
workbench, but its first concrete slice.

The workbench should help with dependency and release research, peer-repository
trend tracking, backlog and decision summarisation, home-ops and dotfiles
coherence, infrastructure questions spanning GitHub/Kubernetes/Cloudflare/
observability/secrets tooling, and safe drafting of changes, issues, and ADRs.

## Decision Drivers

- **No local model inference.** Cluster nodes are not sized for local LLMs and
  there is no dedicated GPU or workstation-class inference node.
- **No PostgreSQL dependency.** The cluster is not currently suited to run
  CloudNativePG or equivalent.
- **Low operational burden.** Components copied from peers must be justified
  against this cluster's constraints rather than adopted wholesale.
- **Spend control.** Cloud inference is acceptable, but provider choice,
  routing, and prompts must avoid uncontrolled API spend.
- **Git remains the source of truth.** Agents may draft, explain, and
  recommend; GitHub issues, ADRs, pull requests, and Flux-managed manifests
  remain the durable control plane. Assistant memory is never authoritative.
- **No Discord bot access.** The design must not depend on monitoring the Home
  Operations Discord server directly.

## Considered Options

| Option                         | Verdict                                                                                                                                                                                      |
| ------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Copy a peer AI stack wholesale | **Rejected.** Peers run local inference, PostgreSQL-backed state, or broader automation surfaces than this cluster should adopt. Useful as domain references, not as a baseline architecture |
| Local inference first          | **Rejected for now.** No suitable compute or GPU; revisit when hardware changes                                                                                                              |
| Open WebUI first               | **Deferred.** A generic chat UI does not solve repository context, MCP access, backlog management, or safe operational workflows                                                             |
| OpenClaw first                 | **Deferred.** Promising as the always-on assistant layer, but it should consume a stable read-only MCP and memory surface rather than define it                                              |
| SearXNG first                  | **Deferred.** Adds operational surface and often Valkey for limiter support. Start with GitHub, Context7, and provider-native search                                                         |
| Dragonfly                      | **Partially adopted.** Justified by LiteLLM cache/router coordination; the first instance is non-persistent and app-local. Durable Redis-compatible state waits for a consumer               |
| Discord bot or scraping        | **Rejected.** Bot access is not expected, and user-token or scraping approaches are not an acceptable foundation                                                                             |

## Decision

Adopt a lightweight AI home-ops workbench in phases:

- **Pull request review:** Claude-backed advisory Renovate PR Review. MiniMax,
  `misospace/pr-reviewer-action`, and model-gateway reviewer designs stay
  deferred pending a separate reviewer decision.
- **Agent workbench:** Hermes as the first interactive surface.
- **MCP gateway:** ToolHive, exposing approved read-only MCPs through explicit
  trust boundaries.
- **Agent clients:** Hermes, future OpenClaw, CI reviewers, and scheduled
  triage jobs are all clients of the same trusted MCP surface.
- **Model routing:** a small internal-only LiteLLM MVP for provider aliases,
  metrics, and cache/router coordination — one replica, no public route, no
  PostgreSQL, no durable LiteLLM state.
- **Memory:** evaluate Memini or similar only after the workbench is useful.
- **Backlog:** GitHub Issues, optionally Projects, with ADRs for durable
  decisions.
- **Community signal:** GitHub-first peer-repo monitoring and sanctioned digest
  exports, with manual paste only as a fallback. The durable capability is
  community trend intelligence from GitHub activity, not Discord ingestion.

Start read-only wherever possible. Write-capable tools are added only after the
read-only workflow has proved useful and the approval boundary is clear.

### MCP trust boundaries

MCPs are grouped by risk, not by novelty.

| Tier                       | Examples                         | Posture                                                                                                                            |
| -------------------------- | -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| Public reference           | Context7                         | Allow early; no secrets in queries                                                                                                 |
| Repository context         | GitHub MCP                       | Read-only or narrowly scoped                                                                                                       |
| Rendered GitOps review     | Konflate MCP                     | Read-only; may reuse the existing Konflate route, which exposes the same read-only rendered data and triggers no renders or writes |
| Observability              | Grafana, metrics MCPs            | Read-only                                                                                                                          |
| GitOps health              | Flux MCP                         | Read-only; prefer summary calls first                                                                                              |
| Cluster operations         | Kubernetes, Talos                | Deferred until RBAC review; read-only first                                                                                        |
| Off-cluster infrastructure | Cloudflare, UniFi                | Deferred; scoped read-only tokens first                                                                                            |
| Secret tooling             | 1Password Developer Environments | Local/dev-first; no whole-vault automation                                                                                         |
| Write-capable automation   | Any mutating infra action        | Deferred; requires explicit human approval                                                                                         |

Treat pull request text and rendered manifests as untrusted prompt input. Add an
explicit authentication and approval boundary before exposing private data, fork
renders, mutating tools, or broader agent access.

### The write boundary

Agents may open issues, pull requests, comments, and review notes. **They must
not mutate the live cluster unless the operator explicitly approves a specific
action.** Semi-autonomous operation starts read-only and evidence-first.

### Repository boundary

The workbench should understand both `home-ops` and the dotfiles repository
while preserving their responsibilities: `home-ops` owns cluster, GitOps,
applications, infrastructure integrations, and manifests; dotfiles owns the
local workstation baseline, shell/editor/agent configuration, and tool
ergonomics; `mise` owns project and local tool activation; 1Password owns secret
and environment contracts. Agents may recommend coordinated changes across
repositories, but each change lands in the repository owning that concern.

### Peer reference posture

Peer repositories are evidence, not target architectures — see
[`../guides/peers.md`](../guides/peers.md). Heavy peer choices such as local
inference, PostgreSQL, vector databases, public authenticated MCP routes,
agentgateway or MCP federation, SearXNG, durable memory, shared Dragonfly, or
large helper CLIs must be justified by concrete local consumers before adoption.

## Consequences

Positive: a concrete starting point for AI-assisted operations without copying a
heavier peer stack; backlog and decisions stay in GitHub and the repository
rather than agent memory; pull request review could proceed before the full
workbench existed; a path to richer automation remains open once read-only
workflows prove useful.

Trade-offs: cloud inference is a recurring-cost dependency; the first version is
less autonomous than some peer stacks; community trend monitoring is weaker than
full Discord access absent a sanctioned digest export; LiteLLM adds another
model gateway surface, so it stays internal and minimal until real consumers
justify expansion; Dragonfly adds another operator and cluster-scoped RBAC, so
its first instance is deliberately non-persistent cache/router state rather than
a durable database.

### Judging it

The workbench succeeds if it improves Renovate review without excessive noise or
cost, produces useful peer-activity summaries, turns vague backlog concerns into
issues or ADR updates, answers repo and operations questions with cited
evidence, preserves secret and repository boundaries, and stays cheap and small
enough not to become a new platform burden.

It fails if it becomes a hidden source of truth, requires broad write
credentials, depends on manual Discord copy-paste for normal value, or pushes
the cluster toward PostgreSQL or local inference before the hardware and
operational model are ready.

## Deferred Decisions

- **Memory:** compare Hermes-local persistence with Memini or another shared
  backend after local memory behaviour is tested.
- **Model routing:** decide which additional clients, if any, should use
  LiteLLM.
- **Reviewer lane:** decide whether to keep, replace, or gate the advisory
  Renovate PR Review once another design proves better release research, cost
  control, and re-review behaviour.
- **Shared state:** decide whether Dragonfly becomes durable or shared only when
  a concrete consumer needs it.
- **OpenClaw:** deploy only after read-only ToolHive and memory boundaries prove
  useful from Hermes.
- **Write access:** require a separate approval boundary before any MCP can
  mutate GitHub, Flux, Kubernetes, or off-cluster infrastructure.

## References

- [Issue #1205: AI-assisted PR review](https://github.com/alex-matthews/home-ops/issues/1205)
- [PR #1202: docs: add repo guidance for agents](https://github.com/alex-matthews/home-ops/pull/1202)
- [`anthropics/claude-code-action`](https://github.com/anthropics/claude-code-action)
- [`stacklok/toolhive`](https://github.com/stacklok/toolhive)
- [`openclaw/openclaw`](https://github.com/openclaw/openclaw)
- [`dragonflydb/dragonfly-operator`](https://github.com/dragonflydb/dragonfly-operator)
- [`eleboucher/memini`](https://github.com/eleboucher/memini)

Peer repository references live in [`../guides/peers.md`](../guides/peers.md).
