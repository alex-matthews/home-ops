# Talos

Declarative [Talos Linux](https://www.talos.dev) machine configuration for the
cluster, composed from multi-document patches. Nothing here is applied
automatically: configs are rendered on demand and pushed to nodes with
`talosctl` through the recipes in `mod.just`.

## Layout

| Path                          | Purpose                                                                   |
| ----------------------------- | ------------------------------------------------------------------------- |
| `cluster.yaml.j2`             | Documents applied to every node                                           |
| `controlplane.yaml.j2`        | Control-plane-only documents, including `machine.type`                    |
| `workers.yaml.j2`             | Worker-only documents (does not exist yet; created with the first worker) |
| `nodes/<role>/<node>.yaml.j2` | Per-node documents (hostname, zone label)                                 |
| `schematic.yaml.j2`           | Shared [Image Factory](https://factory.talos.dev) schematic               |
| `mod.just`                    | Recipes (`just talos ...`)                                                |

## Rendering

`just talos render-config <node>` builds the final machine config in three
layers:

```
talosctl machineconfig patch <(cluster.yaml.j2) \
    -p @<(controlplane.yaml.j2 | workers.yaml.j2) \
    -p @<(nodes/<role>/<node>.yaml.j2)
```

Each layer passes through `minijinja-cli` (strict: an undefined variable fails
the render; the schematic ID arrives as a `-D` define) and `op inject`
(1Password secret resolution) before `talosctl` merges them. Later patches
strategically merge into earlier ones: documents with the same kind and name
are deep-merged, new documents are appended.

Two conventions keep the layers honest:

- **Directory placement is the single source of truth for a node's role.**
  The role patch is chosen by which `nodes/<role>/` directory contains the
  node file, and `machine.type` is set by the role patch, not the node file.
- **Secrets never live in this repo.** Sensitive values are 1Password
  references resolved at render time.

## Gotchas

- `machine.ca` and `cluster.ca` merge as a cert+key **unit**: a patch
  supplying only `key` blanks `crt`. This is why `controlplane.yaml.j2` repeats
  the `crt` references alongside the keys.
- Rendering a worker before `workers.yaml.j2` and `nodes/workers/` exist fails
  loudly. Adding the first worker means creating `workers.yaml.j2` (with
  `machine: { type: worker }` and a `ca` block carrying `crt` only) plus
  `nodes/workers/<node>.yaml.j2`.
- Some v1alpha1 fields are retained on purpose; the reasons are recorded in
  the retention table of #1871. Do not migrate them piecemeal.

## Common tasks

```sh
just talos render-config <node>        # render a node's full machine config to stdout
just talos apply-node <node> --dry-run # show the exact diff Talos would apply
just talos apply-node <node>           # render and apply (talosctl apply-config)
just talos upgrade-node <node>         # upgrade Talos using the schematic image
just talos upgrade-k8s <version>       # upgrade Kubernetes across the cluster
just talos download-image <version>    # fetch a metal ISO from the Image Factory
```

Verify a refactor of these templates by diffing rendered output before and
after, then confirming `apply-node <node> --dry-run` reports "No changes." on
every node. The rollout discipline for anything that changes effective
behaviour is in
[`../docs/operations/node-upgrades.md`](../docs/operations/node-upgrades.md).
