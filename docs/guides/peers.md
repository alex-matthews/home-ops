# Peer Repositories

**When to use:** Peer repositories, how others solved it, upstream pattern, comparison, reference catalog, adopting a pattern.

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

| Peer                   | Go here for                                                                                                                                                           |
| ---------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [onedr0p/home-ops]     | Lean GitOps and app shape, Talos and Flux posture, and the prose style this repo's writing conventions are modelled on                                                |
| [bjw-s-labs/home-ops]  | app-template idioms, from its author; repo-local skills                                                                                                               |
| [buroa/k8s-gitops]     | Lean GitOps shape and Kopiur adoption — ClusterRepository, mover defaults, SnapshotPolicy, passive Restore                                                            |
| [Tanguille/cluster]    | Agent guidance structure: a compact root file routing to topic satellites, and skills that carry their own references and scripts. Also ToolHive and MCPServer detail |
| [joryirving/home-ops]  | Renovate AI review conventions and PR review standards; a generated docs site as contrast                                                                             |
| [eleboucher/homelab]   | AI workbench composition, MCP surfaces, and Memini, which they author                                                                                                 |
| [JJGadgets/Biohazard]  | Agent guidance decomposed by topic rather than centralised in one file                                                                                                |
| [jfroy/flatops]        | Flux and Talos posture, render and CI scoping                                                                                                                         |
| [auricom/home-ops]     | Compact agent guidance led by public-repository posture                                                                                                               |
| [rcdailey/home-ops]    | Tiered agent guidance and numbered decision records, at a scale worth treating as a warning                                                                           |
| [xunholy/k8s-gitops]   | Subagent definitions, a pattern this repo does not use                                                                                                                |
| [carpenike/k8s-gitops] | Running more than one assistant's instructions side by side                                                                                                           |

## Reading peer pull requests

Most peers run Renovate under a custom app identity, so raw pull request volume
is generated and says nothing about house style. Filter to hand-authored pull
requests before drawing any conclusion; on most peers that leaves very little.

[auricom/home-ops]: https://github.com/auricom/home-ops
[bjw-s-labs/home-ops]: https://github.com/bjw-s-labs/home-ops
[buroa/k8s-gitops]: https://github.com/buroa/k8s-gitops
[carpenike/k8s-gitops]: https://github.com/carpenike/k8s-gitops
[eleboucher/homelab]: https://github.com/eleboucher/homelab
[jfroy/flatops]: https://github.com/jfroy/flatops
[JJGadgets/Biohazard]: https://github.com/JJGadgets/Biohazard
[joryirving/home-ops]: https://github.com/joryirving/home-ops
[onedr0p/home-ops]: https://github.com/onedr0p/home-ops
[rcdailey/home-ops]: https://github.com/rcdailey/home-ops
[Tanguille/cluster]: https://github.com/Tanguille/cluster
[xunholy/k8s-gitops]: https://github.com/xunholy/k8s-gitops
