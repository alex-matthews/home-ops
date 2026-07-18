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

## Break-glass paths

If the stable DNS name is unavailable (router or DNS failure):

- **Talos API**: unaffected. `talosctl` targets nodes directly; pin a single
  node with `-n <node> -e <node>` to rule out proxying.
- **Kubernetes API**: point the kubeconfig at a node directly
  (`kubectl --server=https://<node>:6443 ...`). Node identities are in the
  API server certificate by default, so TLS verification still passes.

## Client certificate lifecycle

`just talos cert-check` reports expiry; `just talos cert-renew` renews within
a 30-day window, backing up the previous `talosconfig` and verifying the new
certificate before swapping it in.

## Full rebuild

Cluster rebuild follows the existing bootstrap workflow (`bootstrap/` helm and
kustomize helpers plus the Talos justfile recipes). Machine identity and
secrets are injected from 1Password at render time; nothing in the rebuild
path depends on the removed SAN entries.

## Verification record

- 2026-07-18: direct-node Talos API access proven on all three nodes
  (`talosctl -n <node> -e <node> version` with TLS verification), and
  Kubernetes API TLS proven against a direct node name
  (`kubectl --server=https://m1:6443 version`), both after #1553.
