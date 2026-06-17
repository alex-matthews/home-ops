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
- `backlog.md`, if present, is scratch state.

## Before Editing

- For infra, workflow, GitOps, and automation changes, state the intended diff,
  reference-repo comparison, validation plan, and acceptance criteria before
  editing unless immediate implementation is explicitly requested.
- Read the relevant manifests, workflows, docs, or scripts before proposing a
  fix.
- Keep changes close to the requested scope. If a branch or PR is the active
  iteration surface, amend that branch rather than accumulating work on `main`.
- If a Renovate PR has human companion commits, do not rebase it or let Renovate
  rewrite it unless the user accepts that risk.
- Use peer repositories as design references, not sources to copy blindly.
  onedr0p/home-ops and buroa/k8s-gitops are useful for lean workflow posture;
  bjw-s-labs/home-ops and joryirving/home-ops are useful for agent guidance and
  AI-workbench patterns. Prefer this repo's existing conventions; when modeling
  work on a peer repo, compare the relevant files or PRs and call out material
  divergence before implementation.

## Safety Boundaries

- Do not add bespoke scripts, provider systems, permissions, webhooks, storage,
  auth surfaces, or new public routes without explicit justification and
  approval.
- If live verification shows unexpected behavior, stop and report before
  layering additional fixes.
- Use PR branches for high-risk changes unless the user explicitly approves
  direct-to-main edits.
- Do not make imperative cluster fixes except for diagnostics explicitly
  requested by the user.
- Do not edit generated outputs, rendered manifests, caches, logs, credentials,
  or local auth/session state.
- Do not reformat SOPS-encrypted files; their encrypted document shape is
  intentional.
- Prefer manifest substitution such as `${SECRET_DOMAIN}`, or existing repo
  secrets/vars such as `KONFLATE_URL`, instead of hardcoding hostnames in
  manifests, durable docs, rules files, or workflow defaults. CI, workflow logs,
  generated comments, and status-check links may expose configured public
  hostnames when that is the practical integration shape; do not treat that
  exposure as a blocker by itself.
- Do not modify ExternalSecret names, target secret names, or secret key names
  unless explicitly requested.
- Do not casually change PVC names, storage classes, VolSync or Kopiur objects,
  backup schedules, or restore wiring.
- Do not introduce new operators, CRD families, storage systems, ingress paths,
  or backup systems without a short rationale in the PR or a follow-up note.

## Repo Conventions

- Prefer the existing namespace/app layout under `kubernetes/apps/<namespace>/<app>`.
- Prefer existing bjw-s app-template and Home Operations patterns already
  present in the repo.
- For YAML ordering, use `.agents/instructions/yaml-ordering.instructions.md`
  and the surrounding files' established pattern.
- Keep `just` focused on local/operator workflows. CI should call purpose-built
  tools directly unless there is a specific reason to do otherwise.
- Use `mise exec -- <tool> ...` when invoking repo-pinned tools that may not be
  available on the ambient `PATH`.

## Communication

- Prefer comments and PR bodies that read as operator notes, not AI transcripts.

## Validation

Use the smallest validation set that matches the change. For repo layout, app
patterns, and command examples, see `docs/guides/repo-guide.md`.

When a task is done, state what changed, what was validated, and any remaining
gap or risk plainly.
