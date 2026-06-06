# Home Operations

This repository is the source of truth for my home Kubernetes cluster. The
cluster runs [Talos Linux](https://www.talos.dev/), reconciles from Git with
[Flux](https://fluxcd.io/), and is maintained with
[Renovate](https://github.com/renovatebot/renovate) and
[GitHub Actions](https://github.com/features/actions).

Changes are made in Git, validated in pull requests, merged to `main`, and then
applied by Flux. Local commands are kept in `just` for operator workflows, while
CI runs purpose-built validation tools directly.

## Platform

- Operating system: [Talos Linux](https://www.talos.dev/)
- GitOps: [Flux Operator](https://github.com/controlplaneio-fluxcd/flux-operator)
  and [Flux](https://fluxcd.io/)
- Networking: [Cilium](https://github.com/cilium/cilium),
  [Envoy Gateway](https://github.com/envoyproxy/gateway), and
  [cloudflared](https://github.com/cloudflare/cloudflared)
- DNS: [ExternalDNS](https://github.com/kubernetes-sigs/external-dns),
  Cloudflare, and UniFi
- Secrets: [SOPS](https://github.com/getsops/sops),
  [External Secrets](https://github.com/external-secrets/external-secrets), and
  [1Password Connect](https://1password.com/)
- Storage: [Rook-Ceph](https://github.com/rook/rook),
  [OpenEBS](https://github.com/openebs/openebs), and Synology NFS/SMB
- Backups: [VolSync](https://github.com/backube/volsync)
- Observability:
  [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts),
  [Grafana](https://github.com/grafana/grafana), and
  [Gatus](https://github.com/TwiN/gatus)
- Automation: [Renovate](https://github.com/renovatebot/renovate),
  [Flate](https://github.com/home-operations/flate), and self-hosted GitHub
  Actions runners

## Repository Layout

```text
.
├── bootstrap/          # One-time cluster bootstrap helpers
├── kubernetes/
│   ├── apps/           # Flux-managed applications, grouped by namespace
│   ├── components/     # Shared Kustomize components, SOPS, alerts, VolSync
│   └── flux/cluster/   # Top-level Flux entrypoint used by Flate
├── talos/              # Talos config templates and operator commands
└── volsync/            # Local restore and snapshot helpers
```

Flux enters the cluster at `kubernetes/flux/cluster/ks.yaml`, then reconciles the
applications under `kubernetes/apps`. Most application directories follow this
shape:

```text
kubernetes/apps/<namespace>/<app>/ks.yaml
kubernetes/apps/<namespace>/<app>/app/kustomization.yaml
kubernetes/apps/<namespace>/<app>/app/helmrelease.yaml
kubernetes/apps/<namespace>/<app>/app/ocirepository.yaml
```

Common additions include `externalsecret.yaml`, `pvc.yaml`, `httproute.yaml`,
`servicemonitor.yaml`, dashboards, alerts, and app-specific configuration.

## Automation

Pull requests are checked by GitHub Actions:

- `Flate` renders and validates the Flux tree with missing secrets allowed.
- `Image Pull` uses Flate to calculate new images and pre-pull them on cluster nodes.
- `Labeler` and `Label Sync` keep pull request and repository labels consistent.
- `Renovate` opens dependency update PRs for charts, containers, GitHub Actions, and
  other versioned references.
- `Tag` handles repository release tagging.

The required branch checks are the success aggregators for Flate and Image Pull.
This lets docs-only or non-render-affecting changes pass cleanly while still
blocking Kubernetes changes when rendering fails.

## Local Workflow

Local environment variables are defined in `.mise.toml`; local secrets and auth
state such as `age.key`, `kubeconfig`, `talosconfig`, and `.secrets.env` are
ignored by Git.

Useful entry points:

```sh
just -l
mise install
```

`just` is for local/operator workflows such as bootstrap, Kubernetes diagnostics,
Talos operations, and VolSync restore helpers. CI does not route through `just`
unless a workflow has a specific reason to do so.

## Validation

Use the smallest validation set that matches the change.

Formatting and workflow changes:

```sh
oxfmt --check .
zizmor --offline .github/workflows/*.yaml
```

Flux and Kubernetes changes:

```sh
kubectl kustomize kubernetes/apps/flux-system
FLATE_PATH=./kubernetes/flux/cluster flate test all --allow-missing-secrets
```

Image-affecting Kubernetes changes:

```sh
FLATE_BASE=main FLATE_OUTPUT=json FLATE_PATH=./kubernetes/flux/cluster flate diff images
```

App-specific changes can usually be rendered directly:

```sh
kubectl kustomize kubernetes/apps/<namespace>/<app>/app
```

## Change Safety

This is a live GitOps repository. Take extra care with:

- SOPS-encrypted files, which should not be reformatted or reshaped.
- `ExternalSecret` names, target secret names, and secret key names.
- PVC names, storage classes, access modes, and `dataSourceRef` fields.
- VolSync `ReplicationSource` and `ReplicationDestination` objects.
- Backup retention, schedules, repository secrets, and restore wiring.
- Core platform components such as Rook-Ceph, Cilium, Flux, External Secrets, and
  cert-manager.

Storage, backup, and operator changes should include a clear validation or
rollback path.

## Thanks

This repository builds on patterns from
[onedr0p/cluster-template](https://github.com/onedr0p/cluster-template),
[onedr0p/home-ops](https://github.com/onedr0p/home-ops),
[buroa/k8s-gitops](https://github.com/buroa/k8s-gitops), and the
[Home Operations](https://discord.gg/home-operations) community.

[kubesearch.dev](https://kubesearch.dev/) remains a great way to find examples of
how others deploy applications in similar clusters.

## License

See [LICENSE](./LICENSE).
