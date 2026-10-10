# Repository Guidance

This file is for agents that change the repository. The safety boundaries and
the task router below do not address a kritika review, which follows the
renovate-review skill on a Renovate pull request.

Keep changes small, reviewable and independently reconcilable.

## Entry Point

Read `~/.config/agents/AGENTS.md`; it is a prerequisite and a floor these
rules cannot relax. If unavailable, report that and stop affected work.
This file is the repository authority on change control. Where it and
another repository document disagree, this file wins.
`CLAUDE.md` is its compatibility symlink: edit this file, never the link.
Permissions and hooks belong to dotfiles; their presence is not proof of
working enforcement. Without them, sessions rely on prose.

Read [ARCHITECTURE.md](ARCHITECTURE.md) before substantive work, including
manifest, tooling, workflow, instruction and operational changes, technical
reviews and diagnosis. Only navigation, status checks and literal typo fixes
are exempt. Global and repository rules still apply. Supply the architecture
text to commissioned reviewers.

## Find The Document For The Task

Use this sole task router, one row per document or register entry; follow
relevant pointers and combine routes for validation and safety.
[docs/README.md](docs/README.md) is the index for people and holds
retired-document retrieval, including offline Git commands.

| Task                                                                 | Read                                                                       |
| -------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| Add an app                                                           | [add-app](.agents/skills/add-app/SKILL.md)                                 |
| Change an app: layout, wiring, substitution, persistent state, YAML  | [app-pattern](.agents/skills/add-app/references/app-pattern.md)            |
| Validate before merge; CI scripts, tooling; Renovate review; writing | [CONTRIBUTING](CONTRIBUTING.md)                                            |
| Compare with a peer repository                                       | [peers](docs/peers.md)                                                     |
| Trust a chart source: verify identity, trust classes                 | [chart-trust](docs/policy/decisions.md#chart-trust)                        |
| Exclude a chart from verification; the coverage check                | [chart-exclusions](docs/policy/decisions.md#chart-exclusions-and-coverage) |
| Review a chart or operator upgrade that may carry CRDs               | [crd-upgrades](docs/policy/decisions.md#crd-upgrades)                      |
| Add or change a dependsOn edge                                       | [ordering](docs/policy/decisions.md#reconciliation-ordering)               |
| Choose External Secrets or SOPS                                      | [secrets](docs/policy/decisions.md#secrets-and-substitution)               |
| Backup repositories; what stays unprotected by decision              | [data-protection](docs/policy/decisions.md#data-protection)                |
| Admit a PostgreSQL consumer; database placement                      | [postgresql](docs/policy/decisions.md#postgresql)                          |
| Add workbench clients, tools or automation                           | [workbench-policy](docs/policy/decisions.md#workbench-and-automation)      |
| Merge when a cluster-hosted check cannot report                      | [bypass-merges](docs/policy/decisions.md#bypass-merges)                    |
| Expose, change or remove a public route                              | [public-surfaces](docs/policy/public-surfaces.md)                          |
| Choose a cluster identity for read-only or admin commands            | [access](docs/operations/access.md)                                        |
| Metrics, logs, alerts, silences                                      | [observability](docs/operations/observability.md)                          |
| Backup coverage, maintenance and health                              | [backups](docs/operations/backups.md)                                      |
| Operate the AI workbench, its checks or its login                    | [workbench](docs/operations/workbench.md)                                  |
| Router or NAS management certificates                                | [appliances](docs/operations/appliances.md)                                |
| Reach the cluster when DNS or the router fails                       | [break-glass](docs/recovery/break-glass.md)                                |
| A node that will not boot, or firmware                               | [node-boot](docs/recovery/node-boot.md)                                    |
| Stop workloads, recreate PVCs, hold state across merges              | [maintenance-window](.agents/skills/maintenance-window/SKILL.md)           |
| Restore app/database data; drills, migration, PostgreSQL upgrades    | [restore-data](.agents/skills/restore-data/SKILL.md)                       |
| Upgrade Talos/Kubernetes; failed rollouts; reboots and placement     | [upgrade-nodes](.agents/skills/upgrade-nodes/SKILL.md)                     |
| Machine configuration                                                | [Talos](talos/README.md)                                                   |
| Rebuild or cold start                                                | [bootstrap](bootstrap/README.md)                                           |
| Find a retired document                                              | [docs/README](docs/README.md#retired-documents)                            |

## Treat This Repository As Public

Issues, PRs, release notes and durable prose are public by default. Read the
[writing guidance](CONTRIBUTING.md#write-for-the-record); do not infer house
style.

- Never publish sensitive operational metadata without an explicit request
  for that exact detail: GitHub App/client/installation/ruleset or webhook
  identifiers, 1Password vault/item names, secret key names, private-key or
  credential storage topology, or detailed permission inventories.
- Avoid hardcoded hostnames in manifests, docs, rules and workflow defaults.
  Use `${SECRET_DOMAIN}` or existing secrets/vars.
  Generated CI comments and status links may expose configured public
  hostnames when needed.

## Safety Boundaries

Use Git for managed changes. Imperative fixes require explicitly requested
diagnostics and exact mutation approval. Stop and report unexpected live
behaviour; do not layer further fixes.

Read-only inspection and local validation, rendering and formatting need no
approval. This includes `kubectl get/describe/logs/events/top/auth can-i/diff`,
server dry-run, equivalent Flux/Helm/Talos reads, strictly read-only commands
in existing pods and short-lived local port-forwards. Secret rules still apply.

Ask for the exact action before:

- Any live mutation, including kubectl writes, Flux reconcile/suspend/resume,
  Helm install/upgrade/rollback, Talos apply/upgrade, writing or repairing
  through exec, copying into a pod, and debug workloads. Classify behaviour,
  not the command name.
- Copying anything out of a pod; state the reason.
- Adding/expanding bespoke scripts, provider systems, permissions, webhooks,
  storage, auth surfaces or public routes.
- Introducing operators, CRD families, storage systems, ingress paths or
  backup systems; record the rationale in the PR or a follow-up note.
- Changing ExternalSecret names, target secret names or secret key names;
  PVC names/classes, Kopiur objects, backup schedules or restore wiring.

Never:

- Read or move secret material through exec, cp or port-forward.
- Edit generated outputs, rendered manifests, caches or logs.
- Reformat SOPS-encrypted files.

### Imperative state is a lease, not a lock

A controller can overwrite an imperative change to a field it manages,
including on an apply you trigger through a merge.
Before relying on a hold, identify its owning Git field, controller and next
apply that can clear it. To survive that apply, put the hold in Git or
suspend the responsible controller; check whether a parent can undo the
suspension. Gate destructive steps on fresh, successful state reads.

## Working Here

- Before non-trivial infra, workflow, GitOps or automation edits, state the
  intended diff, validation and done criteria; inspect affected sources.
  Keep this short when implementation is already requested.
- Follow nearby manifests and the [app pattern](.agents/skills/add-app/references/app-pattern.md);
  compare relevant [peer](docs/peers.md)/upstream patterns before introducing
  a new shape.
- Amend the active branch or PR instead of accumulating work on main.
- Do not rebase a Renovate PR with human companion commits, or let Renovate
  rewrite it, without the owner's acceptance of that risk. Read kritika's
  review before merging.
- Use the smallest matching checks from [validation](CONTRIBUTING.md#validate-locally) and
  `mise exec -- <tool> ...` for pinned tools. Report changes, actual
  validation and remaining gaps or risks.

## What You Learn

- Put enforceable instructions in the routed topic; use this file only for
  constraints on agent actions. Promote procedures to skills or operations
  notes only when work recurs and needs repository-specific steps.
- Put shared relationships, ownership and state boundaries in ARCHITECTURE;
  keep task instructions, inventories and incident narratives elsewhere.
- Keep standing decisions and brief reasons under docs/policy/; amend
  them through an approved PR that carries the change rationale. Numbered
  ADRs are retired history, retrievable through docs/README.
- Keep other lessons in `.private/` or memory with their source and
  applicability. History grants no authority; correct or supersede wrong
  lessons in place.
- Remove a section only after verified relocation with a reachable new home,
  replacement by a linked repository command, or when nothing operational
  depends on it and its last verification is dated. Before deleting a
  document, record its path and last-containing commit in docs/README and
  test retrieval.
