# Repo Guide

This is a compact map for this GitOps repo's layout, app patterns, and validation
commands. Agent behavior and change-control rules live in
[`../../AGENTS.md`](../../AGENTS.md).

## Reference Repos

Use peer repositories by domain. They are starting points for comparison, not
constraints or sources to copy blindly. Prefer this repo's existing layout and
conventions when they differ. When a task is modeled on a reference repo,
compare the relevant files or PRs before editing and call out material
divergence before implementation.

| Domain                             | References                                                                                  | Use for                                                                 | Avoid copying                                                              |
| ---------------------------------- | ------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| Lean GitOps posture                | [onedr0p/home-ops], [buroa/k8s-gitops]                                                      | Workflow pruning, Konflate/Downflate posture, app layout, lean CI       | Assuming every omission fits this cluster                                  |
| App and chart conventions          | [onedr0p/home-ops], [buroa/k8s-gitops], [bjw-s-labs/home-ops]                               | HelmRelease value shape, app-template idioms, Home Operations charts    | Reordering or reshaping files against this repo's nearby pattern           |
| AI workbench architecture          | [bjw-s-labs/home-ops], [eleboucher/homelab], [m00nwtchr/homelab-cluster]                    | ToolHive, Hermes, OpenClaw, Memini, LiteLLM, MCP layout                 | Postgres, vector, local inference, or public MCP complexity before needed  |
| MCP and ToolHive patterns          | [eleboucher/homelab], [m00nwtchr/homelab-cluster], [bjw-s-labs/home-ops], [jfroy/flatops]   | vMCP grouping, internal/external routes, OIDC examples, infra MCPs      | Treating public authenticated MCP as the default shape                     |
| ToolHive caveats                   | [rcdailey/home-ops]                                                                         | Session reliability cautions, direct or stdio MCP fallback ideas        | Treating ToolHive as failed here before local evidence shows that          |
| Agent guidance                     | [bjw-s-labs/home-ops], [Tanguille/cluster]                                                  | Minimal AGENTS.md, on-demand `.agents/`, `mise exec --` discipline      | Large all-in-one agent manuals                                             |
| Diagnostic tooling ideas           | [rcdailey/home-ops], [Tanguille/cluster], [eleboucher/homelab]                              | Compact outputs, tools-over-raw-dumps, investigation workflow ideas     | Bespoke helper CLIs until repeated local pain justifies them               |
| Renovate AI review                 | [bo0tzz/clusterfuck], [joryirving/home-ops]                                                 | Research flow, changelog chasing, dead-end handling, re-review behavior | Rebuilding reviewer plumbing without clear quality or cost gain            |
| Model gateway and routing          | [bjw-s-labs/home-ops], [eleboucher/homelab], [joryirving/home-ops]                          | LiteLLM aliases, metrics, provider routing, cost dashboards             | Deploying a gateway before multiple consumers or metrics needs exist       |
| Agentgateway, kgateway, OpenRouter | [m00nwtchr/homelab-cluster], [carpenike/k8s-gitops]                                         | Future provider-routing experiments and simple OpenRouter endpoint use  | Treating them as near-term Envoy or LiteLLM replacements                   |
| Memory, search, reranking          | [eleboucher/homelab], [bjw-s-labs/home-ops], [joryirving/home-ops]                          | Memini, embeddings, reranking, SearXNG/search patterns                  | Adding stateful search or memory substrates before concrete consumers      |
| Mise/toolchain                     | [Tanguille/cluster], [bjw-s-labs/home-ops], [eleboucher/homelab], [bo0tzz/clusterfuck]      | Tool pins, `mise exec --`, human/agent/CI alignment                     | Moving live-cluster operator recipes from `just` to mise tasks             |
| Docs surface                       | [Tanguille/cluster], [bjw-s-labs/home-ops], [waifulabs/infrastructure], [rcdailey/home-ops] | Minimal durable docs, compact agent guidance, selective runbooks        | rcdailey-scale documentation volume or docs-site sprawl                    |
| Public repo guardrails             | [auricom/home-ops], [Tanguille/cluster]                                                     | `${SECRET_DOMAIN}`, public-repo assumptions, durable-doc obfuscation    | Blocking practical CI comments or status URLs solely due hostname exposure |
| Storage and backups                | [onedr0p/home-ops], [buroa/k8s-gitops], [carpenike/k8s-gitops], [bo0tzz/clusterfuck]        | VolSync/Kopia/Kopiur posture, restore docs, PVC caution                 | Assuming peer Kopia choices answer this repo's Restic/webhook questions    |

[auricom/home-ops]: https://github.com/auricom/home-ops
[bjw-s-labs/home-ops]: https://github.com/bjw-s-labs/home-ops
[bo0tzz/clusterfuck]: https://github.com/bo0tzz/clusterfuck
[buroa/k8s-gitops]: https://github.com/buroa/k8s-gitops
[carpenike/k8s-gitops]: https://github.com/carpenike/k8s-gitops
[eleboucher/homelab]: https://github.com/eleboucher/homelab
[jfroy/flatops]: https://github.com/jfroy/flatops
[joryirving/home-ops]: https://github.com/joryirving/home-ops
[m00nwtchr/homelab-cluster]: https://github.com/m00nwtchr/homelab-cluster
[onedr0p/home-ops]: https://github.com/onedr0p/home-ops
[rcdailey/home-ops]: https://github.com/rcdailey/home-ops
[Tanguille/cluster]: https://github.com/Tanguille/cluster
[waifulabs/infrastructure]: https://github.com/waifulabs/infrastructure

## Layout

- `.github/workflows/`: CI, Renovate, Renovate PR Review, and label sync.
- `.agents/instructions/`: narrow reusable agent instructions, currently YAML
  ordering.
- `bootstrap/`: one-time cluster bootstrap helpers.
- `docs/`: durable documentation, including ADRs, guides, and operations docs.
- `kubernetes/apps/`: Flux-managed application declarations.
- `kubernetes/components/`: reusable Kustomize components, including SOPS,
  VolSync, and zeroscaler.
- `kubernetes/flux/cluster`: top-level Flux cluster entrypoint used by render
  tooling.
- `kubernetes/mod.just`: local/operator Kubernetes commands, not CI validation
  glue.
- `talos/`: Talos machine config templates and local helpers.
- `volsync/`: local/operator restore templates and workflows.

## App Pattern

Most applications follow:

```text
kubernetes/apps/<namespace>/<app>/ks.yaml
kubernetes/apps/<namespace>/<app>/app/kustomization.yaml
kubernetes/apps/<namespace>/<app>/app/helmrelease.yaml
kubernetes/apps/<namespace>/<app>/app/ocirepository.yaml
```

Common additions are `externalsecret.yaml`, `pvc.yaml`, `httproute.yaml`,
`servicemonitor.yaml`, dashboards, alerts, or app-specific config files.

The namespace-level `kustomization.yaml` includes each app `ks.yaml`. The app
`ks.yaml` points Flux at the `app/` directory, usually sets `targetNamespace`,
adds `postBuild.substituteFrom` for `cluster-secrets`, and declares dependencies
such as Rook-Ceph when needed.

Prefer existing bjw-s app-template values for app workloads:

- `controllers`
- `defaultPodOptions`
- `service`
- `route`
- `configMaps`
- `persistence`

Use existing image, route, probe, security, and persistence patterns from nearby
apps before adding a new style.

## Sensitive Surfaces

Treat these as high-risk:

- `*.sops.yaml` files: do not reformat or reshape encrypted content.
- `ExternalSecret` names, target secret names, and template keys.
- PVC names, storage classes, access modes, and `dataSourceRef` fields.
- VolSync `ReplicationSource` and `ReplicationDestination` objects.
- Kopiur repository, policy, schedule, restore, and PVC populator wiring.
- Backup retention, schedule, copy method, repository secret, and restore wiring.
- Rook-Ceph, Cilium, Flux, External Secrets, and cert-manager CRDs.
- Namespace names and app names used by Flux, HelmRelease, alerts, dashboards, or
  backup components.
- Hostnames in manifests, durable docs, rules files, or workflow defaults.
  Prefer manifest substitution such as `${SECRET_DOMAIN}`, or existing repo
  secrets/vars such as `KONFLATE_URL`, instead of hardcoding hostnames. CI,
  workflow logs, generated comments, and status-check links may expose
  configured public hostnames when that is the practical integration shape; do
  not treat that exposure as a blocker by itself.

If a change touches storage or backups, prefer a plan-first pass and include a
restore or rollback validation path.

## YAML Ordering

When editing YAML, preserve the repo's established ordering instead of blindly
sorting every key. For reusable ordering rules, see
[`../../.agents/instructions/yaml-ordering.instructions.md`](../../.agents/instructions/yaml-ordering.instructions.md).

If nearby manifests use a chart-specific order, follow the nearby pattern unless
that conflicts with the reusable ordering rules.

## Validation

Use the smallest relevant set.

Formatting and workflow checks:

```sh
oxfmt --check .
actionlint .github/workflows/*.yaml
zizmor --offline .github/workflows/*.yaml
```

Flux and Kubernetes rendering:

```sh
flate test all -p ./kubernetes/flux/cluster --allow-missing-secrets
```

Image diff for Kubernetes app changes:

```sh
flate diff images -p ./kubernetes/flux/cluster -o json
```

For a quick Kustomize-only smoke test, render the touched namespace or app
directory when possible:

```sh
kubectl kustomize kubernetes/apps/<namespace>/<app>/app
```

## Tooling Boundaries

CI runs tools directly. Do not route everything through `just`.

`just` is for local/operator workflows: diagnostics, rendering helpers, live
cluster actions, bootstrap, Talos, and restore operations. Changes to Justfiles
are formatted by Lefthook. Image Pull currently filters on `kubernetes/**/*`, so
changes under `kubernetes/` can trigger it even when the touched file is
local/operator tooling rather than rendered cluster state.

`mise` owns the repo-local environment and toolchain contract. Use it for
environment variables, project-specific tool installation, and reproducible
tool activation. When a required repo tool might not be on `PATH`, prefer:

```sh
mise exec -- <tool> <args>
```

Keep personal workstation preferences, shell/editor configuration, auth state,
and user-specific tools in dotfiles rather than this repo. Do not store secrets,
session state, kubeconfig, talosconfig, or 1Password material in mise config.

Do not move live-cluster or restore recipes from `just` to mise tasks. Mise
tasks may be useful later for small, non-mutating validation aliases, but add
them only when they reduce duplication and do not blur the operator safety
boundary.

If this repo adopts a committed `mise.lock`, treat it as a reproducibility and
supply-chain decision. Renovate can update mise config and lockfiles, but
lockfile refresh requires running `mise lock`, so enable that only after the
Renovate execution model has been reviewed.

## Change Heuristics

- For workflow/tooling changes, validate with `oxfmt`, `actionlint`, `zizmor`,
  and the affected GitHub Actions logic.
- For app changes, validate with app-level `kubectl kustomize`, cluster render
  with Flate, and image diff when image refs may change.
- For storage or backup changes, identify affected PVCs and backup objects
  before editing, then document restore testing.
- For operator or CRD changes, make the PR narrow and include the reason the new
  component is needed.
- For docs-only changes, do not run cluster validation unless the docs changed
  commands or operational instructions.
