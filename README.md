<p align="center">
  <img src="./docs/assets/readme/home-ops-logo.png" width="240" alt="Home Operations logo">
  <br>
  <img src="./docs/assets/readme/home-ops-wordmark.svg" width="420" alt="Home Operations">
</p>

<p align="center">
  <a href="https://www.talos.dev/"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.alexmatthews.xyz%2Fbadges%2Ftalos_version%3Fformat%3Dshields&logo=talos" alt="Talos"></a>
  <a href="https://kubernetes.io/"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.alexmatthews.xyz%2Fbadges%2Fkubernetes_version%3Fformat%3Dshields&logo=kubernetes" alt="Kubernetes"></a>
  <a href="https://fluxcd.io/"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.alexmatthews.xyz%2Fbadges%2Fflux_version%3Fformat%3Dshields&logo=flux" alt="Flux"></a>
</p>

<p align="center">
  <a href="https://github.com/home-operations/kromgo"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.alexmatthews.xyz%2Fbadges%2Fcluster_birth_age%3Fformat%3Dshields" alt="Cluster age"></a>
  <a href="https://github.com/home-operations/kromgo"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.alexmatthews.xyz%2Fbadges%2Fcluster_uptime_age%3Fformat%3Dshields" alt="Cluster uptime"></a>
  <a href="https://github.com/home-operations/kromgo"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.alexmatthews.xyz%2Fbadges%2Fcluster_node_count%3Fformat%3Dshields" alt="Cluster nodes"></a>
  <a href="https://github.com/home-operations/kromgo"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.alexmatthews.xyz%2Fbadges%2Fcluster_pod_count%3Fformat%3Dshields" alt="Cluster pods"></a>
  <a href="https://github.com/home-operations/kromgo"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.alexmatthews.xyz%2Fbadges%2Fcluster_cpu_usage%3Fformat%3Dshields" alt="Cluster CPU"></a>
  <a href="https://github.com/home-operations/kromgo"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.alexmatthews.xyz%2Fbadges%2Fcluster_memory_usage%3Fformat%3Dshields" alt="Cluster memory"></a>
  <a href="https://github.com/home-operations/kromgo"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.alexmatthews.xyz%2Fbadges%2Fcluster_alert_count%3Fformat%3Dshields" alt="Cluster alerts"></a>
</p>

## Overview

This repository is the source of truth for my home Kubernetes cluster. The
cluster runs [Talos Linux](https://www.talos.dev/), reconciles from Git with
[Flux](https://fluxcd.io/), and is maintained with
[Renovate](https://github.com/renovatebot/renovate) and
[GitHub Actions](https://github.com/features/actions).

Changes are made in Git, validated in pull requests, merged to `main`, and then
applied by Flux.

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
  [Konflate](https://github.com/home-operations/konflate), and
  [GitHub Actions](https://github.com/features/actions)

### Hardware

The cluster runs on three Intel NUC 11 Pro i5 nodes. Each node has 64 GiB RAM,
a 500 GB SATA SSD for system and scratch storage, and a dedicated 1 TB NVMe disk
for the replicated Ceph pool.

## Key Paths

```text
.
├── bootstrap/          # One-time cluster bootstrap helpers
├── docs/               # ADRs, repo guidance, and operational notes
├── kubernetes/
│   ├── apps/           # Flux-managed applications, grouped by namespace
│   ├── components/     # Shared Kustomize components, SOPS, alerts, VolSync
│   └── flux/cluster/   # Top-level Flux entrypoint used by render tooling
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

## Automation / CI

Renovate opens dependency update pull requests for charts, containers, GitHub
Actions, and other versioned references.

Pull request checks and reviewers are:

| Check                | Status   | Purpose                                                |
| -------------------- | -------- | ------------------------------------------------------ |
| `Lint`               | Required | Lints workflows and structured files.                  |
| `Image Pull`         | Required | Calculates changed images and pre-pulls them.          |
| `Konflate`           | Required | Posts rendered Flate diffs and checks.                 |
| `Renovate PR Review` | Advisory | Posts Claude-backed reviews for eligible Renovate PRs. |

`Label Sync` keeps repository labels consistent.

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

`just` is for local/operator workflows such as cluster bootstrap, Kubernetes
diagnostics, Talos operations, and VolSync restore helpers.

## Operations Docs

- [AI Workbench Prompts](docs/operations/ai-workbench.md) collects starter
  Hermes and ToolHive MCP prompts.
- [Storage and Backups](docs/operations/storage-and-backups.md) describes the
  current backup posture and backup migration criteria.

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
