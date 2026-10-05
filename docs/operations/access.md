# Access

Verified 2026-10-05 against the repository at `main`; not against the live
cluster.

[The mise configuration](../../.mise/config.toml) selects read-only Kubernetes
and Talos identities by default: `kubeconfig-readonly` and
`talosconfig-readonly` in the main checkout. Entering the checkout in a
mise-activated shell runs `just kube readonly-token`, which mints a fresh
read-only token from the administrative `kubeconfig` once the current one has
under an hour left.

Read-only exec, port-forward and server dry-run may need the administrative
`kubeconfig` or `talosconfig` beside them, without extra approval under
[AGENTS](../../AGENTS.md). Secret rules apply. Pass the file on each command,
because mise overrides an exported `KUBECONFIG` or `TALOSCONFIG`:

```bash
mise exec -- kubectl --kubeconfig <main-checkout>/kubeconfig ...
mise exec -- talosctl --talosconfig <main-checkout>/talosconfig ...
```

Humans can select the administrative profile with `MISE_ENV=admin`; agents do
not switch profiles. Verify successful tunnel and response status before
treating missing data as empty. Granting the read-only identity a new API
group needs a deliberate decision and a `kubectl auth can-i` check, not an
assumed permission.

Worktrees inherit no credentials: mise resolves `KUBECONFIG` against the
worktree, where the untracked credential files do not exist. Pass the main
checkout's path explicitly; do not create or copy credential files.

For lost credentials or DNS/router failure, follow
[break-glass access](../recovery/break-glass.md).
