---
paths:
    - "**/*.sops.yaml"
    - "**/*.sops.yml"
---

# SOPS-encrypted files

Never reformat one. The encrypted document shape is intentional, and a
formatter rewriting it produces a diff that is both unreviewable and lossy.

Editing the plaintext of a secret is a separate decision, covered by the
ask-first list in `AGENTS.md`.
