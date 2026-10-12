# Peer Repositories

Verified 2026-10-05 against the repository at `main`. Catalog rows added or
changed on 2026-10-13 were read at each peer's default branch that day. Peer
repositories change, so read the file before citing it.

Use peers to answer a narrow question: "how have others solved this specific
problem?" They are comparison inputs, not constraints. Inspect the relevant
current files before adopting anything, and call out material differences from
this repo.

"Peer repositories" means the clusters below. Other repositories that sit
alongside this one, such as applications deployed by it, are consumers of these
conventions rather than sources of them.

## Non-goals

- Do not copy public routes, domains, OIDC setup, broad RBAC, storage classes,
  UID/GID values, backup cadence, or branch protection rules from peers.
- Do not add gateway/federation pieces, stateful memory/search substrates,
  local inference, or helper CLIs before a local consumer needs them.
- Do not treat peer CI status names as this repo's branch-protection truth.
- Do not infer a peer's motivation from their configuration. State observed
  facts, and re-check which repository the evidence came from before
  attributing it.

## The catalog

| Peer                                 | Go here for                                                                                                                                                                                                                                                                                                               |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [onedr0p/home-ops]                   | Lean GitOps and app shape, Talos and Flux posture, and the prose style this repo's writing conventions are modelled on                                                                                                                                                                                                    |
| [bjw-s-labs/home-ops]                | app-template idioms, from its author; repo-local skills                                                                                                                                                                                                                                                                   |
| [buroa/home-ops]                     | Lean GitOps shape and Kopiur adoption — ClusterRepository, mover defaults, SnapshotPolicy, passive Restore                                                                                                                                                                                                                |
| [Tanguille/cluster]                  | Agent guidance structure: a compact root file routing to scoped `AGENTS.md` files and topic satellites, and skills that carry their own references and scripts. Also ToolHive and MCPServer detail with gVisor by default, recurring simplification PRs evidenced by a rendered diff, and a charts-mirror existence check |
| [joryirving/home-ops]                | Renovate AI review conventions and evidence providers (rendered diff, upstream release notes, chart-default drift against the values set), and the LiteLLM platform behind them: pooled fallbacks, per-consumer keys, a model-reference check and failure alerts. A generated docs site as contrast                       |
| [eleboucher/homelab]                 | AI workbench composition, MCP surfaces, and Memini, which they author                                                                                                                                                                                                                                                     |
| [jfroy/flatops]                      | Flux and Talos posture, render and CI scoping                                                                                                                                                                                                                                                                             |
| [auricom/home-ops]                   | Compact agent guidance led by public-repository posture                                                                                                                                                                                                                                                                   |
| [xunholy/k8s-gitops]                 | Subagent definitions, a pattern this repo does not use                                                                                                                                                                                                                                                                    |
| [LukeEvansTech/talos-cluster]        | Public-repository leak guards over tracked files, commit messages and PR bodies; a health-verdict skill that reports an unchecked area as blind rather than healthy; ToolHive gateway, telemetry and MCP RBAC detail                                                                                                      |
| [Exikle/Artemis-Cluster]             | Agent guardrails as code: a destructive-command guard generated from one rule table, a lint for agent-config wiring, and behavioural evals of the instructions compared across commits                                                                                                                                    |
| [Aviator-Coding/home-ops]            | Agent guidance at scale: a root file of tripwires routing to per-subsystem skills with references, held small by size budgets in CI                                                                                                                                                                                       |
| [keiretsu-labs/kubernetes-manifests] | Repository invariant checks: version coupling, backup coverage with reasoned exemptions, and quiet check tools built for agents                                                                                                                                                                                           |
| [aumer-amr/labv2]                    | Network policy as a guarded layer: per-namespace default-deny Kustomizations, host-allowlisted egress for agents, and CI that refuses to drop the gates                                                                                                                                                                   |
| [tscibilia/home-ops]                 | Docs split into current state and write-once decisions, with a pre-commit check that names in the docs still exist in the manifests                                                                                                                                                                                       |
| [gtw2/home-ops]                      | Manifest comments that record measurements, kritika review rules restated from a short `AGENTS.md`, and a model evaluation built from the cluster's own incidents                                                                                                                                                         |
| [h-wb/home-ops]                      | mise as the only tool and task runner (monorepo task roots, hk hooks, fnox bootstrap secrets), and Renovate auto-merge gated on a kritika approval, as contrast to this repo's allowlist                                                                                                                                  |
| [ekenheim/home-ops-upgrade]          | A sandbox for coding agents with a written trust model and known gaps; LiteLLM teams, per-consumer key stores and plan-quota alerts. Its LLM platform follows joryirving's                                                                                                                                                |

## Beyond the catalog

The catalog is the short list, not the field. If the question is "has anyone
solved this", also sweep the cluster repositories onedr0p keeps starred. That
list is curated by the author of the pattern most of this repo follows, and it
is where a practice shows up before it reaches the peers above. The topic
filter misses untagged repositories, so widen it when a search comes up empty:

```bash
gh api users/onedr0p/starred --paginate \
  --jq '.[] | select((.topics // []) | index("k8s-at-home")) | .full_name'
```

Treat a hit there as a lead to inspect, not a precedent to cite, until the
file has been read.

## Reading peer pull requests

Most peers run Renovate under a custom app identity, so raw pull request volume
is generated and says nothing about house style. Filter to hand-authored pull
requests before drawing any conclusion; on most peers that leaves very little.

[aumer-amr/labv2]: https://redirect.github.com/aumer-amr/labv2
[auricom/home-ops]: https://redirect.github.com/auricom/home-ops
[Aviator-Coding/home-ops]: https://redirect.github.com/Aviator-Coding/home-ops
[bjw-s-labs/home-ops]: https://redirect.github.com/bjw-s-labs/home-ops
[buroa/home-ops]: https://redirect.github.com/buroa/home-ops
[ekenheim/home-ops-upgrade]: https://redirect.github.com/ekenheim/home-ops-upgrade
[eleboucher/homelab]: https://redirect.github.com/eleboucher/homelab
[Exikle/Artemis-Cluster]: https://redirect.github.com/Exikle/Artemis-Cluster
[gtw2/home-ops]: https://redirect.github.com/gtw2/home-ops
[h-wb/home-ops]: https://redirect.github.com/h-wb/home-ops
[jfroy/flatops]: https://redirect.github.com/jfroy/flatops
[joryirving/home-ops]: https://redirect.github.com/joryirving/home-ops
[keiretsu-labs/kubernetes-manifests]: https://redirect.github.com/keiretsu-labs/kubernetes-manifests
[LukeEvansTech/talos-cluster]: https://redirect.github.com/LukeEvansTech/talos-cluster
[onedr0p/home-ops]: https://redirect.github.com/onedr0p/home-ops
[Tanguille/cluster]: https://redirect.github.com/Tanguille/cluster
[tscibilia/home-ops]: https://redirect.github.com/tscibilia/home-ops
[xunholy/k8s-gitops]: https://redirect.github.com/xunholy/k8s-gitops
