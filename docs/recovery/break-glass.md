# Break-Glass Access

Verified 2026-10-05 against the repository at `main`; the direct paths were
not exercised.

Credential creation/renewal and recipes doing it are human-only. After rebuild,
a human re-establishes Kubernetes access; old tokens do not survive identity
recreation. Talos credentials remain usable only with unchanged trust and
validity. The [certificate recipes](../../talos/mod.just) own expiry/renewal;
preserve the old configuration and verify the replacement before switching.

The talosconfig names nodes by hostname, which needs the router's DNS, and
the repository records no node addresses. Keep each node's direct address
beside the break-glass credentials, and preverify reachability and TLS while
the cluster works. Use the existing credentials and verified direct address:

```bash
mise exec -- talosctl --talosconfig <existing-file> -n <direct-IP> -e <direct-IP> version
mise exec -- kubectl --kubeconfig <existing-file> --server=https://<direct-IP>:6443 get nodes
```

Hostname access does not prove an outage path. Record the date each direct
path was last tested beside its address, and repeat after router upgrades;
neither a default SAN nor a direct address guarantees access past a failed
router.

For ordinary read-only and administrative command selection, follow
[access](../operations/access.md).
