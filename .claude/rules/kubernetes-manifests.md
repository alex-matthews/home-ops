---
paths:
    - "kubernetes/**/*.yaml"
    - "kubernetes/**/*.yml"
---

# Editing manifests here

Read `docs/guides/app-pattern.md` for repository layout and app file shape, and
`docs/guides/yaml-ordering.md` for key ordering, before shaping a new file or
reordering an existing one. Follow the surrounding files where the guides are
silent.

These are triggers, not copies: the guides remain the single home for the
detail, and this file exists so a session touching a manifest has been told to
read them rather than having to decide to.
