# Peer Repositories

**When to use:** Peer repositories, how others solved it, upstream pattern, comparison, reference catalog, adopting a pattern.

Use peer repositories to answer a narrow question: "how have others solved this
specific problem?" They are comparison inputs, not constraints. Before adopting
a pattern, inspect the relevant current files or pull requests and call out
material differences from this repo.

"Peer repositories" means this catalog — the home-ops and k8s-gitops clusters
listed below. Other repositories that happen to sit alongside this one, such as
applications deployed by it, are consumers of these conventions rather than
sources of them; do not compare against those.

## Non-goals

- Do not copy public routes, domains, OIDC setup, broad RBAC, storage classes,
  UID/GID values, backup cadence, or branch protection rules from peers.
- Do not add gateway/federation pieces, stateful memory/search substrates,
  local inference, or helper CLIs before a local consumer needs them.
- Do not treat peer CI status names as this repo's branch-protection truth.
- Do not infer a peer's motivation from their configuration. State observed
  facts, and re-check which repository the evidence came from before
  attributing it.

## Where to look

| Question                                                                 | Repositories                                                                                                                                                                                                  |
| ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Lean GitOps and app shape, Kustomize components, namespace layout        | [onedr0p/home-ops], [buroa/k8s-gitops], [bjw-s-labs/home-ops], [perryhuynh/homelab]                                                                                                                           |
| Render and CI posture, workflow scoping, render checks                   | [onedr0p/home-ops], [waifulabs/infrastructure], [Tanguille/cluster], [jfroy/flatops], [auricom/home-ops], [rcdailey/home-ops]                                                                                 |
| AI workbench architecture, Hermes/ToolHive/LiteLLM composition           | [bjw-s-labs/home-ops], [eleboucher/homelab], [m00nwtchr/homelab-cluster]                                                                                                                                      |
| MCP and ToolHive patterns, MCPGroup/vMCP shape, read-only infra MCPs     | [bjw-s-labs/home-ops], [eleboucher/homelab], [perryhuynh/homelab], [rafaribe/home-ops], [jfroy/flatops], [Tanguille/cluster]                                                                                  |
| Model gateway, aliases, tiers, fallback routing                          | [bjw-s-labs/home-ops], [eleboucher/homelab], [joryirving/home-ops], [Tanguille/cluster]                                                                                                                       |
| Agentgateway, Gateway API, provider routing                              | [perryhuynh/homelab], [m00nwtchr/homelab-cluster], [joryirving/home-ops]                                                                                                                                      |
| Memory, search, embeddings, reranking                                    | [eleboucher/homelab], [bjw-s-labs/home-ops], [m00nwtchr/homelab-cluster], [rafaribe/home-ops]                                                                                                                 |
| Renovate AI review: rubric, changelog tracing, re-review behaviour, cost | [bjw-s-labs/home-ops], [bo0tzz/clusterfuck], [joryirving/home-ops], [Tanguille/cluster], [billimek/k8s-gitops], [wrmilling/k3s-gitops], [misospace/pr-reviewer-action], [koki-develop/claude-renovate-review] |
| Agent-facing documentation shape                                         | See [Agent-facing documentation](#agent-facing-documentation) below                                                                                                                                           |
| Toolchain and local workflow, `mise exec --`, task/just boundaries       | [Tanguille/cluster], [bjw-s-labs/home-ops], [auricom/home-ops], [rcdailey/home-ops]                                                                                                                           |
| Minimal durable docs, compact runbooks, docs-site contrast               | [Tanguille/cluster], [jfroy/flatops], [waifulabs/infrastructure], [rcdailey/home-ops], [joryirving/home-ops]                                                                                                  |
| Kopiur adoption, ClusterRepository, mover defaults, passive Restore      | [home-operations/kopiur], [buroa/k8s-gitops], [eleboucher/homelab], [onedr0p/home-ops]                                                                                                                        |

## Agent-facing documentation

Surveyed 2026-07-31 across this catalog and onedr0p's home-ops-repos list:
13 of 26 repositories carry agent-facing documentation. Shapes worth knowing:

| Repository             | Shape                                                                                                                                                                                                                                                                                                               |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [Tanguille/cluster]    | 33-line `AGENTS.md` routing to `.agents/` satellites — `common-operations`, `learned-preferences`, `learned-workspace` — plus eight skills carrying `references/` and `scripts/`. Each satellite opens with trigger keywords, and the learned files are declared authoritative and maintained by continual learning |
| [rcdailey/home-ops]    | 601-line `AGENTS.md` tiered Breaking / Conventions / Reference, with `docs/architecture/` and numbered `docs/decisions/` alongside                                                                                                                                                                                  |
| [joryirving/home-ops]  | 194-line `AGENTS.md` whose second half is PR review standards; `.agents/instructions/`, skills, and an mdBook under `docs/src/`                                                                                                                                                                                     |
| [JJGadgets/Biohazard]  | No root file at all; `.agents/` decomposed into eight topic files — app-deployment, ci, core-components, flux, networking, new-app, security, storage                                                                                                                                                               |
| [bjw-s-labs/home-ops]  | 3-line `AGENTS.md` importing one instruction file and pointing at skills. The minimal end of the range                                                                                                                                                                                                              |
| [auricom/home-ops]     | 88 lines, opening with "CRITICAL: Treat This Repo As Public"                                                                                                                                                                                                                                                        |
| [xunholy/k8s-gitops]   | `.claude/agents/` subagent definitions only: dependency-mapper, flux-troubleshooter, gitops-deployer, resource-optimizer, security-auditor                                                                                                                                                                          |
| [carpenike/k8s-gitops] | `CLAUDE.md` plus `.github/copilot-instructions.md` — multi-assistant, with long `docs/*-GUIDE.md` companions                                                                                                                                                                                                        |

Also carrying agent docs, unread beyond their file layout: [jfroy/flatops]
(`AGENTS.md` and `CLAUDE.md`), [eleboucher/homelab] (`CLAUDE.md` only),
[okwilkins/h8s], [coolguy1771/home-ops], [Diaoul/home-ops] and
[solidDoWant/infra-mk3] (skills only), [mcfio/talos-n150-cluster]
(`docs/agent-notes.md`).

**[onedr0p/home-ops] has none.** The most-cited repository in this catalog
carries no `AGENTS.md`, `CLAUDE.md`, or `.agents/` directory. Do not go looking
for one.

### Where the reviewer's own prompt lives

[bjw-s-labs/home-ops] and [joryirving/home-ops] both keep the AI reviewer's
system prompt in-repo at `.agents/instructions/pr-review.instructions.md`,
appended to the action's bundled prompt rather than replacing it. Both are
largely noise suppression: do not flag patterns the repo documents as
intentional, and keep digest-only reviews short. That is the lever to reach for
when reviewer output is being ignored — see
[`validation.md`](validation.md).

## Prose and pull request conventions

Most peers run Renovate under a custom app identity, so their pull request
volume is generated and tells you nothing about house style. Filter to
hand-authored pull requests before drawing conclusions.

Surveyed 2026-07-31: [onedr0p/home-ops] is the only peer with a substantial
body of hand-authored pull requests (49). [joryirving/home-ops] has 11.
[bjw-s-labs/home-ops] and [buroa/k8s-gitops] write essentially empty bodies,
which makes them a restraint benchmark rather than a style source.
[jfroy/flatops] and [rcdailey/home-ops] had none, so do not use them for pull
request or report shape despite the CI rows above.

onedr0p uses no fixed template: 21 of 49 bodies carry no headings at all, and
mean body length is longer than this repo's. Length is not the differentiator —
see [`pr-and-issue-writing.md`](pr-and-issue-writing.md) for what is.

[auricom/home-ops]: https://github.com/auricom/home-ops
[billimek/k8s-gitops]: https://github.com/billimek/k8s-gitops
[bjw-s-labs/home-ops]: https://github.com/bjw-s-labs/home-ops
[bo0tzz/clusterfuck]: https://github.com/bo0tzz/clusterfuck
[carpenike/k8s-gitops]: https://github.com/carpenike/k8s-gitops
[coolguy1771/home-ops]: https://github.com/coolguy1771/home-ops
[Diaoul/home-ops]: https://github.com/Diaoul/home-ops
[buroa/k8s-gitops]: https://github.com/buroa/k8s-gitops
[eleboucher/homelab]: https://github.com/eleboucher/homelab
[home-operations/kopiur]: https://github.com/home-operations/kopiur
[jfroy/flatops]: https://github.com/jfroy/flatops
[JJGadgets/Biohazard]: https://github.com/JJGadgets/Biohazard
[joryirving/home-ops]: https://github.com/joryirving/home-ops
[koki-develop/claude-renovate-review]: https://github.com/koki-develop/claude-renovate-review
[m00nwtchr/homelab-cluster]: https://github.com/m00nwtchr/homelab-cluster
[misospace/pr-reviewer-action]: https://github.com/misospace/pr-reviewer-action
[mcfio/talos-n150-cluster]: https://github.com/mcfio/talos-n150-cluster
[okwilkins/h8s]: https://github.com/okwilkins/h8s
[onedr0p/home-ops]: https://github.com/onedr0p/home-ops
[perryhuynh/homelab]: https://github.com/perryhuynh/homelab
[rafaribe/home-ops]: https://github.com/rafaribe/home-ops
[rcdailey/home-ops]: https://github.com/rcdailey/home-ops
[solidDoWant/infra-mk3]: https://github.com/solidDoWant/infra-mk3
[Tanguille/cluster]: https://github.com/Tanguille/cluster
[waifulabs/infrastructure]: https://github.com/waifulabs/infrastructure
[wrmilling/k3s-gitops]: https://github.com/wrmilling/k3s-gitops
[xunholy/k8s-gitops]: https://github.com/xunholy/k8s-gitops
[wrmilling/k3s-gitops]: https://github.com/wrmilling/k3s-gitops
