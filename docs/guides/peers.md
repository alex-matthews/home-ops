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

| Question                                                                   | Repositories                                                                                                                                                                           |
| -------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Lean GitOps and app shape, Kustomize components, namespace layout          | [onedr0p/home-ops], [buroa/k8s-gitops], [bjw-s-labs/home-ops], [perryhuynh/homelab]                                                                                                    |
| Render and CI posture, workflow scoping, render checks                     | [onedr0p/home-ops], [waifulabs/infrastructure], [Tanguille/cluster], [jfroy/flatops], [auricom/home-ops], [rcdailey/home-ops]                                                          |
| AI workbench architecture, Hermes/ToolHive/LiteLLM composition             | [bjw-s-labs/home-ops], [eleboucher/homelab], [m00nwtchr/homelab-cluster]                                                                                                               |
| MCP and ToolHive patterns, MCPGroup/vMCP shape, read-only infra MCPs       | [bjw-s-labs/home-ops], [eleboucher/homelab], [perryhuynh/homelab], [rafaribe/home-ops], [jfroy/flatops]                                                                                |
| Model gateway, aliases, tiers, fallback routing                            | [bjw-s-labs/home-ops], [eleboucher/homelab], [joryirving/home-ops], [Tanguille/cluster]                                                                                                |
| Agentgateway, Gateway API, provider routing                                | [perryhuynh/homelab], [m00nwtchr/homelab-cluster], [joryirving/home-ops]                                                                                                               |
| Memory, search, embeddings, reranking                                      | [eleboucher/homelab], [bjw-s-labs/home-ops], [m00nwtchr/homelab-cluster], [rafaribe/home-ops]                                                                                          |
| Renovate AI review: rubric, changelog tracing, re-review behaviour, cost   | [bo0tzz/clusterfuck], [joryirving/home-ops], [Tanguille/cluster], [billimek/k8s-gitops], [wrmilling/k3s-gitops], [misospace/pr-reviewer-action], [koki-develop/claude-renovate-review] |
| Compact agent guidance, on-demand `.agents/` shape, public-repo guardrails | [Tanguille/cluster], [bjw-s-labs/home-ops], [jfroy/flatops], [auricom/home-ops], [rcdailey/home-ops]                                                                                   |
| Toolchain and local workflow, `mise exec --`, task/just boundaries         | [Tanguille/cluster], [bjw-s-labs/home-ops], [auricom/home-ops], [rcdailey/home-ops]                                                                                                    |
| Minimal durable docs, compact runbooks, docs-site contrast                 | [Tanguille/cluster], [jfroy/flatops], [waifulabs/infrastructure], [rcdailey/home-ops]                                                                                                  |
| Kopiur adoption, ClusterRepository, mover defaults, passive Restore        | [home-operations/kopiur], [buroa/k8s-gitops], [eleboucher/homelab], [onedr0p/home-ops]                                                                                                 |

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
[buroa/k8s-gitops]: https://github.com/buroa/k8s-gitops
[eleboucher/homelab]: https://github.com/eleboucher/homelab
[home-operations/kopiur]: https://github.com/home-operations/kopiur
[jfroy/flatops]: https://github.com/jfroy/flatops
[joryirving/home-ops]: https://github.com/joryirving/home-ops
[koki-develop/claude-renovate-review]: https://github.com/koki-develop/claude-renovate-review
[m00nwtchr/homelab-cluster]: https://github.com/m00nwtchr/homelab-cluster
[misospace/pr-reviewer-action]: https://github.com/misospace/pr-reviewer-action
[onedr0p/home-ops]: https://github.com/onedr0p/home-ops
[perryhuynh/homelab]: https://github.com/perryhuynh/homelab
[rafaribe/home-ops]: https://github.com/rafaribe/home-ops
[rcdailey/home-ops]: https://github.com/rcdailey/home-ops
[Tanguille/cluster]: https://github.com/Tanguille/cluster
[waifulabs/infrastructure]: https://github.com/waifulabs/infrastructure
[wrmilling/k3s-gitops]: https://github.com/wrmilling/k3s-gitops
