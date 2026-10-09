# Context for kritika

This repository is the Flux source of truth for one Talos cluster. When
sources disagree, trust them in this order: the manifests under
`kubernetes/`, `talos/` and `bootstrap/` at the pull request's head;
a flate render of the head; upstream release notes and source; then
prose.

`ARCHITECTURE.md` explains how the parts fit together, and
`docs/policy/decisions.md` records standing decisions by anchor. Both are
prose in the order above: where one disagrees with a manifest, report the
disagreement rather than treating the change as wrong.

Workload secrets reach the cluster through ExternalSecrets from 1Password
and one SOPS file; public hostnames are `${SECRET_DOMAIN}`. CI lints
workflows, shell scripts and formatting, verifies chart signatures and
checks that images pull, and Konflate posts its own render summary: do not
repeat what they report.
