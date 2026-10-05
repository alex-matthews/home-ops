# Access

Verified 2026-10-05 against the repository at `main`; not against the live
cluster.

[The mise configuration](../../.mise/config.toml) selects read-only Kubernetes
and Talos identities by default. Read-only exec, port-forward and server
dry-run may need an existing admin identity, without extra approval under
[AGENTS](../../AGENTS.md). Secret rules apply. Name it per command: mise can
override exported variables:

```bash
mise exec -- kubectl --kubeconfig <existing-admin-file> ...
mise exec -- talosctl --talosconfig <existing-admin-file> ...
```

Humans can select the administrative profile with `MISE_ENV=admin`; agents do
not switch profiles. Verify successful tunnel and response status before
treating missing data as empty. Adding an API group needs deliberate
read-access consideration and a capability check, not an assumed permission.

Worktrees inherit no credentials: mise resolves `KUBECONFIG` against the
worktree, where the untracked credential files do not exist. Pass the main
checkout's path explicitly; do not create or copy credential files.

For lost credentials or DNS/router failure, follow
[break-glass access](../recovery/break-glass.md).
