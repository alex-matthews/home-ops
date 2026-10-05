# Talos

Verified 2026-10-05 against the repository at `main`; not against the
nodes.

Template edits require a human render/apply. [Node upgrades](../.agents/skills/upgrade-nodes/references/node-upgrades.md)
cover version rollouts; [bootstrap](../bootstrap/README.md) covers rebuild.
The [recipes](mod.just) own command mechanics.

## Layering

Configuration combines cluster, role and node templates in that order.
Later patches can override earlier ones: the role directory selects the role,
so node patches must not declare `machine.type`. Undefined template values
fail rendering. A per-node schematic is a complete override, not a delta;
the recipe returns its resolved ID. Adding the first worker requires supplying
its role and node files.

These templates resolve secret references during rendering. A human runs
`just talos render-config <node>`; agents must not print or write resolved
credential material. Compare render results safely for a template refactor,
without treating a changed document order as automatically harmless.

## Applying

A human runs `just talos apply-node <node> --dry-run`, inspects the proposed
effect, then applies to one node. Read the affected resources back and confirm
health before the rest; finish with a no-change dry-run on every node.
Schema validation alone does not establish runtime effect. Plan CRI
customisation changes as drain windows. Migrating legacy bind-mounted `/etc`
files to `EtcFileConfig` can require a per-node reboot; verify affected
resources before continuing.

## Legacy fields and migration discipline

Some `v1alpha1` fields remain coupled by migration constraints, tabled with
their reasons in the previous version of this file (see the [retired
documents](../docs/README.md#retired-documents)). Do not independently move kubelet, CA, service-account, cluster-name or
endpoint configuration without checking the exact pinned version's document
types and handlers. Preserve the kubelet bind mount supporting OpenEBS local
storage and paired CA certificate/key patching; a partial pair can overwrite
its partner. That table's encoding/support observations apply only to the
Talos version it names.
Apply new document kinds only after nodes support them, and verify each
migration's effects.
