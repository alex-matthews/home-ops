# Repository Guidance

This repository is the GitOps source of truth for the cluster. Keep changes
small, reviewable, and independently reconcilable.

## Entry Points

- This file is the canonical agent entrypoint and the authority on change
  control. Where it and another document disagree, this file wins.
- `docs/guides/` holds the working references. Read the one the task needs:
    - `cluster-model.md`: how a change reaches the cluster, secrets, backups,
      and which surfaces are high-risk to touch.
    - `app-pattern.md`: repository layout and app file shape.
    - `yaml-ordering.md`: key ordering conventions for YAML edits.
    - `validation.md`: what to run, what each check proves, CI and tooling
      boundaries, bypass merges.
    - `peers.md`: reference repository catalog and how to use it.
    - `pr-and-issue-writing.md`: issue bodies, pull request descriptions, and
      comments. Read it before posting or editing any GitHub prose.
- `.agents/skills/`: task recipes such as `add-app`. Load a skill only when
  performing that task. Load `maintenance-window` before planning or executing
  any window that stops workloads, deletes or recreates PVCs, or holds
  imperative cluster state across a merge.

## Before Editing

- For non-trivial infra, workflow, GitOps, and automation changes, state the
  intended diff, the validation plan, and the done criteria before editing.
  Keep this short when immediate implementation is requested.
- Read the relevant manifests, workflows, docs, or scripts before proposing a
  fix.
- Keep changes close to the requested scope. If a branch or PR is the active
  iteration surface, amend that branch rather than accumulating work on `main`.
- If a Renovate PR has human companion commits, do not rebase it or let Renovate
  rewrite it unless the user accepts that risk.
- Compare against peer or upstream patterns where one exists, using the catalog
  in `docs/guides/peers.md`. Avoid bespoke glue unless local constraints
  require it.
- Before merging a Renovate PR, read the Renovate PR Review bot's comment. It
  analyses the chart templates, which is where a chart's surface actually
  changes — release notes describe the code and routinely miss it. See
  `docs/guides/validation.md`.
- Verify a convention's scope before writing it as a default. Grep the set it
  actually applies to; a pattern that holds for one component or one app is not
  a repository-wide rule. State the scoping rule rather than a count.

## Safety Boundaries

- Do not add or expand bespoke scripts, provider systems, permissions, webhooks,
  storage, auth surfaces, or public routes without explicit justification and
  approval.
- If live verification shows unexpected behavior, stop and report before
  layering additional fixes.
- Use PR branches for high-risk changes unless the user explicitly approves
  direct-to-main edits.
- Do not make imperative cluster fixes except for diagnostics explicitly
  requested by the user.
- Read-only cluster inspection counts as diagnostics: `kubectl get`,
  `describe`, `logs`, `events`, `top`, `auth can-i`, `diff`, and
  `apply --dry-run=server`, plus the equivalent `flux`, `helm`, and `talosctl`
  read commands.
- Imperative cluster state is a lease, not a lock. Anything set with `kubectl`
  on a Flux-managed object is cleared by the next successful apply of the
  Kustomization that owns it — often an apply you trigger yourself. Before
  relying on any imperative hold, name the Git field that owns it and the next
  apply that will clear it; if it must survive, put it in Git or suspend the
  controller. Gate destructive steps on freshly re-read state, never on state
  asserted earlier in the session.
- Treat every mutating cluster command as an imperative fix that needs explicit
  user approval of the exact action first: `kubectl apply`, `create`, `delete`,
  `edit`, `patch`, `replace`, `scale`, `rollout`, `annotate`, `label`,
  `cordon`, `drain`; `flux reconcile`, `suspend`, `resume`; `helm` install,
  upgrade, or rollback; `talosctl` apply or upgrade; and anything else that
  changes live state.
- Classify `kubectl exec`, `port-forward`, `cp`, and `debug` by behavior, not
  name. Acceptable diagnostics: exec'ing a strictly read-only command in an
  existing pod, or a short-lived local port-forward to inspect an internal
  endpoint. Ask first for anything that changes state: exec'ing commands that
  write files or run repairs, `kubectl cp` into a pod, and `kubectl debug`,
  which creates debug workloads. Copying out of a pod is state-preserving but
  can extract data — state the reason before copying anything out, and never
  use exec, cp, or port-forward to read or move secret material.
- Do not edit generated outputs, rendered manifests, caches, logs, credentials,
  or local auth/session state.
- Do not reformat SOPS-encrypted files; their encrypted document shape is
  intentional.
- Avoid hardcoding hostnames in manifests, durable docs, rules files, or
  workflow defaults. Prefer `${SECRET_DOMAIN}` or existing repo secrets/vars
  such as `KONFLATE_URL`; generated CI comments and status links may expose
  configured public hostnames when needed.
- Never publish sensitive operational metadata to GitHub issues, PR bodies, PR
  comments, or other public prose unless the user explicitly asks for that exact
  detail to be public. This includes GitHub App/client/installation/ruleset
  identifiers, webhook identifiers, 1Password vault/item names, secret key names,
  private-key or credential storage topology, and detailed permission
  inventories.
- Do not modify ExternalSecret names, target secret names, or secret key names
  unless explicitly requested.
- Do not casually change PVC names, storage classes, Kopiur objects,
  backup schedules, or restore wiring.
- Do not introduce new operators, CRD families, storage systems, ingress paths,
  or backup systems without a short rationale in the PR or a follow-up note.

## Repo Conventions

- Follow nearby manifests and the app patterns in `docs/guides/app-pattern.md`
  before introducing a new shape.
- For YAML ordering, use `docs/guides/yaml-ordering.md` and the surrounding
  files' established pattern.
- Keep `just` focused on local/operator workflows. CI should call purpose-built
  tools directly unless there is a specific reason to do otherwise.
- Use `mise exec -- <tool> ...` when invoking repo-pinned tools that may not be
  available on the ambient `PATH`.
- Use Conventional Commit titles: `type(scope): summary`. Keep the subject in
  the imperative and let the body carry the reasoning.
- Do not add AI attribution or generated-by trailers to commits, pull request
  descriptions, or code comments.

## Recording What You Learn

When a session establishes a durable working preference or a non-obvious fact
about this repository, write it into the document that owns the topic. Do not
leave it in agent-private memory: other agents and other clients cannot read
it, so guidance held by one assistant is guidance every other one ignores.

- A prose, review, or issue-hygiene convention → `docs/guides/pr-and-issue-writing.md`.
- A cluster, secret, or storage fact → `docs/guides/cluster-model.md`, or the
  relevant note under `docs/operations/`.
- A caveat about what a check does or does not prove →
  `docs/guides/validation.md`.
- A peer-comparison scoping rule → `docs/guides/peers.md`.
- A rule that changes what an agent is allowed to do → this file.
- If nothing owns it, add a guide rather than widening this file.

Record the evidence alongside the rule. The observation that produced it is
what lets a later reader judge whether it still holds, and a rule with no
evidence is the first thing to rot.

## Communication

Treat GitHub issues, PRs, release notes, and durable repo prose as public by
default. The writing standards and the pre-publication safety checklist are in
[`docs/guides/pr-and-issue-writing.md`](docs/guides/pr-and-issue-writing.md);
read it rather than inferring house style from surrounding text.

When reporting to the user, state what changed, what was validated, and any
remaining gap or risk plainly.

## Validation

Use the smallest validation set that matches the change. Commands, per-change
heuristics, and the caveats that make a given check trustworthy are in
`docs/guides/validation.md`.
