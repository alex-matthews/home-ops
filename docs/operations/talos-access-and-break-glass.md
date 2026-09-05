# Talos Access and Break-Glass

Records the supported API identities and the recovery access paths after the
certificate-SAN cleanup (#1543, #1546, #1553; tracked by #1530). Keep this
short and factual; update it whenever API identities or access paths change.

## Supported API identities

- The Kubernetes API is addressed by the stable internal DNS name only. That
  name is maintained manually on the router, not by the cluster.
- The API server certificate carries the stable DNS name plus the Talos
  default SANs (localhost and the node identities). Direct
  LoadBalancer-VIP-by-IP TLS is intentionally unsupported.
- The Talos API is addressed per node. The repo `talosconfig` lists the node
  hostnames as both endpoints and nodes; no VIP or proxy sits in the path.

## Session identities (two per plane)

Since #1921 the mise environment injects read-only credentials by default;
the administrative files remain beside them. An interactive operator
sitting selects them wholesale with `export MISE_ENV=admin` (profile in
`.mise/config.admin.toml`, covering the just recipes too); agent sessions
never set the profile and use the per-command flags below.

- Kubernetes: `kubeconfig-readonly` authenticates the
  `kube-system/agent-readonly` ServiceAccount — get/list/watch everywhere,
  core-group Secrets excluded, no mutations. Port-forward and exec are
  subresource creates, so they are denied too: a read that needs either
  (an Alertmanager or Prometheus query, a read-only command in a pod)
  takes the administrative kubeconfig as a flag. A denied port-forward
  prints its error to stderr and leaves the pipeline reading nothing, so
  check the connection before trusting an empty result. The identity's objects live in
  `kubernetes/apps/kube-system/agent-access/`. Its token is minted per
  sitting: `just kube readonly-token` requests an 8-hour token through the
  TokenRequest API with the administrative kubeconfig and writes
  `kubeconfig-readonly`; the mise `enter` hook runs it, and it is a no-op
  while the current token has more than an hour left. No long-lived token
  exists. Revoke early by deleting the ServiceAccount, which Flux recreates
  with a new UID so every token issued to the old one stops validating.
  Administrative path: `mise exec -- kubectl --kubeconfig ./kubeconfig ...`
  (a flag, because the mise environment overrides an exported variable).
- Talos: `talosconfig-readonly` carries `os:reader` — reads work, sensitive
  resources (machine config among them) and all mutations are denied.
  Re-mint from the admin credential:
  `talosctl config new talosconfig-readonly --roles os:reader -n m1 -e m1`
  (a single node must be pinned). Administrative path:
  `mise exec -- talosctl --talosconfig ./talosconfig ...`.
- When an operator introduces a new API group, the PR that introduces it
  adds the group to the `agent-readonly-extra` ClusterRole (or the operator
  ships an aggregate-to-view label); re-run the capability listing after.

## Break-glass paths

If the stable DNS name is unavailable (router or DNS failure):

- **Talos API**: unaffected. `talosctl` targets nodes directly; pin a single
  node with `-n <node> -e <node>` to rule out proxying.
- **Kubernetes API**: point the kubeconfig at a node directly
  (`kubectl --server=https://<node>:6443 ...`). Node identities are in the
  API server certificate by default, so TLS verification still passes.

Re-test both paths after every UniFi OS upgrade. They depend on router
behaviour that a firmware change can alter, and the failure is silent until the
moment you need them.

## Client certificate lifecycle

`just talos cert-check` reports expiry; `just talos cert-renew` renews within
a 30-day window, backing up the previous `talosconfig` and verifying the new
certificate before swapping it in.

## Full rebuild

Sequence, guards, and cold-start behaviour are in
[`cluster-rebuild.md`](cluster-rebuild.md); the operator-side commands are in
[`../../bootstrap/README.md`](../../bootstrap/README.md). Machine identity
and secrets are injected from the password manager at render time, so both
Talos identities survive a rebuild; the read-only Kubernetes identity's
tokens do not, because the ServiceAccount is recreated, and one is minted
again with `just kube readonly-token` once the API answers.

## Verification record

- 2026-07-18: direct-node Talos API access proven on all three nodes
  (`talosctl -n <node> -e <node> version` with TLS verification), and
  Kubernetes API TLS proven against a direct node name
  (`kubectl --server=https://<node>:6443 version`), both after #1553.
