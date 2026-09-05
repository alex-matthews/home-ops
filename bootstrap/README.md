# Bootstrap

Operator-facing notes for `just bootstrap cluster`, which takes three
freshly reset Talos nodes to a running Flux. Planning, guards, and what the
control loop does after Flux takes over are in
[`../docs/operations/cluster-rebuild.md`](../docs/operations/cluster-rebuild.md).

## Before you run it

- An interactive shell with the administrative identities selected
  (`export MISE_ENV=admin`); the recipes do not work on the read-only pair.
- Access to the password manager: machine configs render their secrets at
  apply time and prompt once per node.
- The SOPS age key available to the tooling, for the encrypted secrets the
  base stage applies.
- Console or physical access to the nodes. A node that stays silent after a
  reboot is hung in firmware and needs a power-button hold; see
  [`../docs/operations/node-firmware-and-boot.md`](../docs/operations/node-firmware-and-boot.md).
- Every node in maintenance mode, confirmed with the insecure Talos API
  (`talosctl -n <node> -e <node> version --insecure`).

## What the recipe does

`just bootstrap cluster` runs six stages in order and stops at the first
failure. Each stage is also a private recipe in `mod.just` for re-running
one step.

1. `nodes` renders and applies each node's machine config in insecure mode.
   A node that already has a config is skipped rather than failed.
2. `k8s` bootstraps etcd on the first endpoint and retries until the
   cluster reports it as already bootstrapped.
3. `kubeconfig` fetches a kubeconfig pointed at the first node directly,
   because the stable DNS name resolves to a LoadBalancer address that does
   not exist yet.
4. `base` waits for the nodes to register, then applies the namespaces,
   the SOPS-encrypted bootstrap secrets, and the CRDs listed in
   `helmfile/crds.yaml`.
5. `apps` syncs `helmfile/apps.yaml`: the CNI, cluster DNS, the registry
   mirror, cert-manager, external-secrets, the secrets connector, and
   finally the Flux operator and instance. These charts are pulled by helm
   directly from the pins in the repository's `ocirepository.yaml` files,
   outside source-controller, so no signature verification runs on this
   path; see the chart-source verification issue for that caveat.
6. `kubeconfig` runs again against the stable DNS name once the Flux-managed
   networking has advertised the API address.

On the 2026-09-03 rebuild the six stages took eight minutes; Flux was
applying `main` within the same minute the instance came up.

## After it returns

Flux owns everything from here. Expect storage to be the slowest component
to arrive and everything that needs it to wait; the rebuild note lists what
that looks like and which waits have been made automatic. Verify with the
read-only checks in the rebuild note rather than by watching pods.

Two things stay manual today:

- the read-only agent kubeconfig needs a fresh token
  (`just kube readonly-token`), because Flux recreates the ServiceAccount;
- if the Actions runner listener crash-loops against a runner set that no
  longer exists, delete the AutoscalingListener object and the controller
  recreates it.
