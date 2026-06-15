# Repository Guidance

This repository is the GitOps source of truth for the cluster. Keep changes
small, reviewable, and independently reconcilable.

## Guardrails

- For infra, workflow, GitOps, and automation changes, state the intended diff,
  reference-repo comparison, validation plan, and acceptance criteria before
  editing unless the user explicitly asks for immediate implementation.
- Do not add bespoke scripts, provider systems, permissions, webhooks, storage,
  auth surfaces, or new public routes without explicit justification and
  approval.
- Treat onedr0p/home-ops and buroa/k8s-gitops patterns as constraints. Explain
  any divergence before implementing it.
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
- Prefer the existing namespace/app layout under `kubernetes/apps/<namespace>/<app>`.
- Prefer existing bjw-s app-template and Home Operations patterns already
  present in the repo.
- Keep `just` focused on local/operator workflows. CI should call purpose-built
  tools directly unless there is a specific reason to do otherwise.

## Validation

Use the smallest validation set that matches the change and report the commands
run. For repo layout, app patterns, and command examples, see
`docs/guides/repo-guide.md`.

When a task is done, state what changed, what was validated, and any remaining
gap or risk plainly.
