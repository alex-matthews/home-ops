# Context for kritika

This repository is the Flux source of truth for one Talos cluster. When
sources disagree, trust them in this order: the manifests under
`kubernetes/`, `talos/` and `bootstrap/` at the pull request's head;
Konflate's render of the pull request; upstream release notes and source;
then prose.

`docs/` is being rewritten and is excluded from reviews and similar-code
context. Open a file there only when a change names it, and never treat it
as evidence that a change is wrong. `AGENTS.md` governs agents that change
the repository, not reviews.

Workload secrets reach the cluster through ExternalSecrets from 1Password
and one SOPS file; public hostnames are `${SECRET_DOMAIN}`. CI lints
workflows, shell scripts and formatting, verifies chart signatures and
checks that images pull, and Konflate posts its own render summary: do not
repeat what they report.
