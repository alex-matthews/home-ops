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
  [OpenEBS](https://github.com/openebs/openebs), and Synology NFS
- Backups: [VolSync](https://github.com/backube/volsync)
- Observability:
  [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts),
  [Grafana](https://github.com/grafana/grafana), and
  [Gatus](https://github.com/TwiN/gatus) via gatus-sidecar
- Automation: [Renovate](https://github.com/renovatebot/renovate),
  [Flate](https://github.com/home-operations/flate), and self-hosted GitHub
  Actions runners

## Key Paths

```text
.
├── .github/            # GitHub Actions, labels, and repository automation
├── bootstrap/          # One-time cluster bootstrap helpers
├── docs/               # ADRs, repo guidance, and operational notes
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

Renovate opens dependency update pull requests for charts, containers, GitHub
Actions, and other versioned references.

Pull requests are checked by GitHub Actions:

- `Flate` renders and validates the Flux tree with missing secrets allowed.
- `Image Pull` uses Flate to calculate new images and pre-pull them on cluster nodes.
- `Konflate` runs in-cluster and posts native advisory pull request comments and
  checks from rendered Flate diffs.
- `Renovate Research Review` can post advisory Claude-backed research reviews on
  eligible same-repository Renovate pull requests.
- `Labeler` and `Label Sync` keep pull request and repository labels consistent.

Flate and Image Pull are the required branch-check gates. Konflate and Renovate
Research Review are advisory.

See [Repo Guide](docs/guides/repo-guide.md) for local validation commands and
repository conventions.

## Local Workflow

Local environment variables and repo toolchain activation are defined in
`.mise/config.toml`; local secrets and auth state such as `age.key`,
`kubeconfig`, `talosconfig`, and `.secrets.env` are ignored by Git.

Useful entry points:

```sh
mise install
just -l
```

`just` is for local/operator workflows such as bootstrap, Kubernetes diagnostics,
Talos operations, and VolSync restore helpers. CI does not route through `just`
unless a workflow has a specific reason to do so.

## Operations Docs

- [AI Workbench Prompts](docs/operations/ai-workbench.md) collects starter
  Hermes and ToolHive MCP prompts.
- [Storage and Backups](docs/operations/storage-and-backups.md) describes the
  current backup posture and Kopia migration criteria.

## Thanks

This repository builds on patterns from
[onedr0p/home-ops](https://github.com/onedr0p/home-ops),
[buroa/k8s-gitops](https://github.com/buroa/k8s-gitops),
[bjw-s-labs/home-ops](https://github.com/bjw-s-labs/home-ops), and the
[Home Operations](https://discord.gg/home-operations) community.

[kubesearch.dev](https://kubesearch.dev/) remains a great way to find examples of
how others deploy applications in similar clusters.

## License

See [LICENSE](./LICENSE).
