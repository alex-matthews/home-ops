# Talos

Machine configuration for the cluster's Talos Linux nodes, composed from
multi-document patches. Flux does not touch this directory. Nothing here
reaches a node until an operator renders and applies it through the
`just talos` recipes.

## Layout

| Path                                    | Purpose                                                       |
| --------------------------------------- | ------------------------------------------------------------- |
| `cluster.yaml.j2`                       | Documents applied to every node                               |
| `controlplane.yaml.j2`                  | Control-plane-only documents, including `machine.type`        |
| `workers.yaml.j2`                       | Worker-only documents, absent until the first worker is added |
| `nodes/<role>/<node>.yaml.j2`           | Per-node documents (hostname, zone label)                     |
| `nodes/<role>/<node>.schematic.yaml.j2` | Optional per-node schematic override                          |
| `schematic.yaml.j2`                     | Shared [Image Factory](https://factory.talos.dev) schematic   |
| `mod.just`                              | Recipes (`just talos ...`)                                    |

## Rendering

`just talos render-config <node>` builds a node's machine configuration in
three layers, where `<role>` is `controlplane` or `workers`:

```
talosctl machineconfig patch <(cluster.yaml.j2) \
    -p @<(<role>.yaml.j2) \
    -p @<(nodes/<role>/<node>.yaml.j2)
```

`minijinja-cli` renders each layer with `strict = true` from the repository's
`.minijinja.toml`, so an undefined variable fails the render. Templates do not
read the process environment. The schematic ID is the only template variable,
and `render-config` passes it as a `-D` define. `op inject` then resolves the
1Password references. `talosctl` merges the layers in order. A later document
with the same kind and name deep-merges into the earlier one, and a new
document is appended.

Two conventions keep the layers honest:

- The directory a node file sits in decides its role. `render-config` picks
  the role patch from `nodes/<role>/`, and the role patch sets `machine.type`.
  A node file does not declare `machine.type`; nothing enforces this, because
  the node layer is patched last and would win.
- Secrets never live in this repository. Every sensitive value is a 1Password
  reference, which `op inject` resolves at render time.

## Schematic

The schematic customises the Image Factory build (system extensions, kernel
args). `just talos schematic-id [node]` POSTs it to the factory and gets back
a content-addressed ID, stored nowhere in the repository. `cluster.yaml.j2`
templates the ID into the `UnattendedInstallConfig` installer image, which
`upgrade-node` reads; `download-image` puts the same ID in the ISO URL.

Resolution is per node. `nodes/<role>/<node>.schematic.yaml.j2` wins if
present, otherwise the shared `schematic.yaml.j2` applies. An override is a
complete file, not a delta, for a node whose hardware diverges from the fleet.

## Applying

Run `just talos apply-node <node> --dry-run` first. Talos prints the exact
diff it would apply and whether it needs a reboot. `talosctl validate` checks
shape, not effect, so the dry-run is the only honest answer to "what does this
change". Apply to one node, read the affected resources back, and only then
the rest. A second dry-run should report `No changes.`.

[`../docs/operations/node-upgrades.md`](../docs/operations/node-upgrades.md)
holds the rollout discipline for a change that alters effective behaviour and
the side effects some document kinds carry.

## What stays in v1alpha1

Talos 1.14 accepts every field below in the legacy `v1alpha1` document (the
top-level `machine:` and `cluster:` block), and each stays there for a reason.
Do not migrate one of these fields on its own. Read its reason first, because
several rows depend on each other.

| Field                                                                                           | Why it stays                                                                                                                                               |
| ----------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `machine.kubelet`                                                                               | `KubeletConfig` has no `extraMounts`, and the `/var/openebs/local` bind mount backs the `openebs-hostpath` storage class                                   |
| `machine.ca`, `cluster.ca`, `cluster.aggregatorCA`, `cluster.etcd.ca`, `cluster.serviceAccount` | The document forms take raw PEM, and the stored values are base64 that `op inject` passes through undecoded                                                |
| `machine.token`, `cluster.token`                                                                | No document form exists                                                                                                                                    |
| `cluster.clusterName`, `cluster.controlPlane.endpoint`                                          | `KubeClusterConfig` must move together with `KubeServiceAccountConfig` (Talos's `machined` panics otherwise), and the CA row blocks that                   |
| `cluster.etcd` (`advertisedSubnets`, `extraArgs`)                                               | Talos 1.14 has no etcd document                                                                                                                            |
| `machine.features` (`rbac`, `apidCheckExtKeyUsage`, `diskQuotaSupport`)                         | Not deprecated                                                                                                                                             |
| `machine.network.interfaces` (one DHCP link selected by MAC prefix)                             | Deferred to a networking change of its own, because a wrong link document strands a node until someone is on site (the nodes have no remote power control) |

## Gotchas

- `machine.ca` and `cluster.ca` merge as a cert+key unit. A patch supplying
  only `key` blanks `crt`, so `controlplane.yaml.j2` repeats the `crt`
  references alongside the keys. A patch that omits `ca` entirely leaves both
  intact, so a worker patch needs no `ca` block.
- Rendering a worker fails until `workers.yaml.j2` and `nodes/workers/` exist.
  Adding the first worker means creating `workers.yaml.j2` with
  `machine: { type: worker }` plus `nodes/workers/<node>.yaml.j2`.
- Verify a refactor of these templates by diffing the rendered output before
  and after, then by confirming that a dry-run on every node reports
  `No changes.`. One diff is expected and harmless. Patches append, so moving
  a document between layers reorders the rendered file, and the dry-run shows
  the reorder once as a move-only diff.
