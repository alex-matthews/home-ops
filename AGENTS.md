# Repository Guidance

This repository is the GitOps source of truth for the cluster. Keep changes
small, reviewable, and independently reconcilable.

## Entry Points

- This file is the canonical agent entrypoint.
- `docs/guides/repo-guide.md` contains repo layout, app patterns, and
  validation commands. Read it before non-trivial repo, workflow, or GitOps
  edits.
- `.agents/instructions/` is reserved for narrow reusable instructions such as
  YAML ordering. Load only the files relevant to the task.
- `.agents/skills/` holds task recipes such as `add-app`. Load a skill only
  when performing that task.
- `backlog.md`, if present, is scratch state.

## Before Editing

- For non-trivial infra, workflow, GitOps, and automation changes, briefly state
  the intended diff, relevant reference or upstream pattern when useful,
  validation plan, and done criteria before editing. Keep this short when
  immediate implementation is requested.
- Read the relevant manifests, workflows, docs, or scripts before proposing a
  fix.
- Keep changes close to the requested scope. If a branch or PR is the active
  iteration surface, amend that branch rather than accumulating work on `main`.
- If a Renovate PR has human companion commits, do not rebase it or let Renovate
  rewrite it unless the user accepts that risk.
- For non-trivial changes, compare against relevant peer or upstream patterns
  when useful. Use `docs/guides/repo-guide.md` for the reference repo catalog,
  and avoid bespoke glue unless local constraints require it.

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
- Do not casually change PVC names, storage classes, VolSync or Kopiur objects,
  backup schedules, or restore wiring.
- Do not introduce new operators, CRD families, storage systems, ingress paths,
  or backup systems without a short rationale in the PR or a follow-up note.

## Repo Conventions

- Follow nearby manifests and the app patterns in `docs/guides/repo-guide.md`
  before introducing a new shape.
- For YAML ordering, use `.agents/instructions/yaml-ordering.instructions.md`
  and the surrounding files' established pattern.
- Keep `just` focused on local/operator workflows. CI should call purpose-built
  tools directly unless there is a specific reason to do otherwise.
- Use `mise exec -- <tool> ...` when invoking repo-pinned tools that may not be
  available on the ambient `PATH`.

## Communication

- Prefer comments and PR bodies that read as operator notes, not AI transcripts.
- Treat GitHub issues, PRs, release notes, and durable repo prose as public by
  default. Keep them summary-level and use redacted categories when evidence
  would otherwise expose exact identifiers, credential topology, public route
  maps, or control mechanisms.
- Before posting or updating GitHub text, review it for unnecessary identifiers,
  credential relationships, permission details, public endpoint inventories, and
  state-changing automation details. Keep exact values in terminal output,
  private notes, or local validation context instead of public prose.

## Validation

Use the smallest validation set that matches the change. For repo layout, app
patterns, and command examples, see `docs/guides/repo-guide.md`.

When a task is done, state what changed, what was validated, and any remaining
gap or risk plainly.
