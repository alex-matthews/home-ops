# Repository Guidance

This repository is the GitOps source of truth for the cluster. Keep changes
small, reviewable, and independently reconcilable.

## Entry Point

This file is the canonical agent entrypoint and, among this repository's own
documents, the authority on change control: where it and another document here
disagree, this file wins. It adds to the global agent rules in
`~/.config/agents/AGENTS.md` and does not relax them — those set a floor this
file can raise and not lower. Harness-specific enforcement — permission
allowlists and hooks — is managed in the dotfiles layer, not here. A machine
without that layer runs sessions on prose alone.

`CLAUDE.md` beside it is a compatibility symlink to this file, because Claude
Code reads that name and not `AGENTS.md`. Edit this file, never the link.

## Find The Document For The Task

Start with the matching task; follow relevant pointers, and apply the
validation and safety routes when they also match. This table is the only
index; `docs/README.md` describes the directories and points back here.

| Task                                                                                                                                                            | Read                                              |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------- |
| Add an app                                                                                                                                                      | `.agents/skills/add-app/SKILL.md`                 |
| Change an app: values, images, storage, routes, substitution, removal                                                                                           | `docs/guides/app-pattern.md`                      |
| Understand how a change reaches the cluster: Flux ordering, `dependsOn`, secrets, substitution                                                                  | `docs/guides/cluster-model.md`                    |
| Validate before merge, or change CI, a workflow, or repo tooling: what to run, what each check proves, bypass merges, the Renovate review, `just` versus `mise` | `docs/guides/validation.md`                       |
| Order keys in YAML                                                                                                                                              | `docs/guides/yaml-ordering.md`                    |
| Compare with a peer repository                                                                                                                                  | `docs/guides/peers.md`                            |
| Write an issue, pull request body, comment, or ADR                                                                                                              | `docs/guides/writing.md`                          |
| Plan or execute a window that stops workloads, deletes or recreates PVCs, or holds imperative state across a merge                                              | `.agents/skills/maintenance-window/SKILL.md`      |
| Recover: rebuild or cold start                                                                                                                                  | `docs/operations/cluster-rebuild.md`              |
| Recover: reach the cluster when DNS or the router fails                                                                                                         | `docs/operations/talos-access-and-break-glass.md` |
| Recover: a node that will not boot, or firmware                                                                                                                 | `docs/operations/node-firmware-and-boot.md`       |
| Operate: backups, restores, PVC lifecycle, Kopiur                                                                                                               | `docs/operations/storage-and-backups.md`          |
| Operate: Talos or Kubernetes node upgrades                                                                                                                      | `docs/operations/node-upgrades.md`                |
| Operate: Talos machine configuration                                                                                                                            | `talos/README.md`                                 |
| Operate: metrics, logs, alerts, silences                                                                                                                        | `docs/operations/observability.md`                |
| Operate: appliance management TLS                                                                                                                               | `docs/operations/appliance-tls.md`                |
| Operate: what is exposed publicly and how                                                                                                                       | `docs/operations/public-surfaces.md`              |
| Operate: the Hermes and ToolHive workbench                                                                                                                      | `docs/operations/ai-workbench.md`                 |
| Why the AI workbench is shaped as it is                                                                                                                         | `docs/adr/0001-ai-home-ops-workbench.md`          |
| Why backups use two independent repositories                                                                                                                    | `docs/adr/0002-kopiur-backup-storage-shape.md`    |
| Why chart sources are verified, and the trust classes                                                                                                           | `docs/adr/0003-helm-chart-source-verification.md` |
| Why public services carry the controls they do                                                                                                                  | `docs/adr/0004-public-surface-controls.md`        |

A retired document is still readable from the local clone. `docs/README.md`
records the last commit that contained each one and its path; search that
commit with `git grep -n -e '<phrase>' <sha> -- docs .agents/skills` and read
the file with
`git show <sha>:<path>`.

## Treat This Repository As Public

Issues, pull requests, release notes, and durable repo prose are public by
default.

Never publish sensitive operational metadata to GitHub issues, PR bodies, PR
comments, or other public prose unless the user explicitly asks for that exact
detail to be public. This includes GitHub App/client/installation/ruleset
identifiers, webhook identifiers, 1Password vault/item names, secret key names,
private-key or credential storage topology, and detailed permission
inventories.

Avoid hardcoding hostnames in manifests, durable docs, rules files, or workflow
defaults. Prefer `${SECRET_DOMAIN}` or existing repo secrets/vars such as
`KONFLATE_URL`; generated CI comments and status links may expose configured
public hostnames when needed.

Writing standards and the pre-publication checklist are in
[`docs/guides/writing.md`](docs/guides/writing.md). Read it rather than
inferring house style from surrounding text.

## Safety Boundaries

Changes reach the cluster through Git. Imperative fixes are for diagnostics the
user explicitly requested, and if live verification shows unexpected behaviour,
stop and report rather than layering further fixes.

### Always

Read-only inspection needs no approval: `kubectl get`, `describe`, `logs`,
`events`, `top`, `auth can-i`, `diff`, and `apply --dry-run=server`, plus the
equivalent `flux`, `helm`, and `talosctl` read commands. Also allowed are
exec'ing a strictly read-only command in an existing pod, and a short-lived
local port-forward to inspect an internal endpoint.

Local validation, rendering, and formatting are always allowed.

### Ask first

Get explicit user approval of the exact action before:

- Any mutating cluster command: `kubectl apply`, `create`, `delete`, `edit`,
  `patch`, `replace`, `scale`, `rollout`, `annotate`, `label`, `cordon`,
  `drain`; `flux reconcile`, `suspend`, `resume`; `helm` install, upgrade, or
  rollback; `talosctl` apply or upgrade; and anything else that changes live
  state.
- `kubectl exec` running commands that write files or run repairs, `kubectl cp`
  into a pod, and `kubectl debug`, which creates debug workloads. Classify
  these by behaviour, not by command name.
- Copying anything out of a pod. It is state-preserving but can extract data,
  so state the reason first.
- Adding or expanding bespoke scripts, provider systems, permissions, webhooks,
  storage, auth surfaces, or public routes.
- Introducing new operators, CRD families, storage systems, ingress paths, or
  backup systems. Record the rationale in the PR or a follow-up note.
- Modifying ExternalSecret names, target secret names, or secret key names.
- Changing PVC names, storage classes, Kopiur objects, backup schedules, or
  restore wiring.

### Never

- Use `exec`, `cp`, or `port-forward` to read or move secret material.
- Edit generated outputs, rendered manifests, caches, or logs.
- Reformat SOPS-encrypted files; their encrypted document shape is intentional.

### Imperative state is a lease, not a lock

Anything set with `kubectl` on a Flux-managed object is cleared by the next
successful apply of the Kustomization that owns it — often an apply you trigger
yourself. Before relying on any imperative hold, name the Git field that owns
it and the next apply that will clear it; if it must survive, put it in Git or
suspend the controller. Gate destructive steps on freshly re-read state, never
on state asserted earlier in the session.

## Working Here

- For non-trivial infra, workflow, GitOps, and automation changes, state the
  intended diff, the validation plan, and the done criteria before editing.
  Keep this short when immediate implementation is requested. Read the
  manifests, workflows, docs, or scripts the change touches first.
- Follow nearby manifests and the app patterns in `docs/guides/app-pattern.md`
  before introducing a new shape. Compare against peer or upstream patterns
  where one exists, using the catalog in `docs/guides/peers.md`.
- If a branch or pull request is the active iteration surface, amend it rather
  than accumulating work on `main`.
- If a Renovate PR has human companion commits, do not rebase it or let
  Renovate rewrite it unless the user accepts that risk. Before merging a
  Renovate PR, read the Renovate PR Review bot's comment; it analyses the
  chart templates, which is where a chart's surface actually changes.
- Use the smallest validation set that matches the change; the commands and
  what each proves are in `docs/guides/validation.md`. Use
  `mise exec -- <tool> ...` for repo-pinned tools that may not be on the
  ambient `PATH`.
- When reporting to the user, state what changed, what was validated, and any
  remaining gap or risk plainly.

## What You Learn

Two kinds of thing are maintained here, and durability alone admits neither.
An **instruction** is an enforceable constraint: an operating limit, a
recovery step, an approval boundary, a public-safety rule. It goes in the
document the table routes to, or in this file only if it changes what an agent
is allowed to do. A **procedure** is recurring work that needs
repository-specific steps; it becomes a skill or an operations note only once
the work recurs and the steps are this repository's own.

Everything else is a **lesson**: a correction, an observation, a workaround a
later version retired. Keep it as a note with the pull request, issue, or
commit it came from and the condition it held under, in `.private/` or harness
memory until a shared store exists. A note is history, never an instruction: it
grants no permission and overrides nothing current. A lesson found wrong is
corrected or superseded in place, keeping its source and its applicability.

A section leaves a document when a repository command regenerates it and the
document links to that command, or when nothing operational depends on it and
its last verification is dated. Before removing a document, add its path and
the last commit that contains it to the retired table in `docs/README.md`, so
the retrieval commands above work offline.
