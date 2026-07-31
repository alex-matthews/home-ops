<p align="center">
  <img src="./docs/assets/readme/home-ops-logo.png" width="240" alt="Home Operations logo">
  <br>
  <img src="./docs/assets/readme/home-ops-wordmark.svg" width="420" alt="Home Operations">
</p>

<p align="center">
  <a href="https://www.talos.dev/"><img src="https://kromgo.alexmatthews.xyz/badges/talos_version" alt="Talos"></a>
  <a href="https://kubernetes.io/"><img src="https://kromgo.alexmatthews.xyz/badges/kubernetes_version" alt="Kubernetes"></a>
  <a href="https://fluxcd.io/"><img src="https://kromgo.alexmatthews.xyz/badges/flux_version" alt="Flux"></a>
</p>

<p align="center">
  <a href="https://github.com/home-operations/kromgo"><img src="https://kromgo.alexmatthews.xyz/badges/cluster_birth_age" alt="Cluster age"></a>
  <a href="https://github.com/home-operations/kromgo"><img src="https://kromgo.alexmatthews.xyz/badges/cluster_uptime_age" alt="Cluster uptime"></a>
  <a href="https://github.com/home-operations/kromgo"><img src="https://kromgo.alexmatthews.xyz/badges/cluster_node_count" alt="Cluster nodes"></a>
  <a href="https://github.com/home-operations/kromgo"><img src="https://kromgo.alexmatthews.xyz/badges/cluster_pod_count" alt="Cluster pods"></a>
  <a href="https://github.com/home-operations/kromgo"><img src="https://kromgo.alexmatthews.xyz/badges/cluster_cpu_usage" alt="Cluster CPU"></a>
  <a href="https://github.com/home-operations/kromgo"><img src="https://kromgo.alexmatthews.xyz/badges/cluster_memory_usage" alt="Cluster memory"></a>
  <a href="https://github.com/home-operations/kromgo"><img src="https://kromgo.alexmatthews.xyz/badges/cluster_alert_count" alt="Cluster alerts"></a>
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
- Backups: [Kopiur](https://github.com/home-operations/kopiur) to Garage S3 and
  Cloudflare R2
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

## Networking

The cluster sits behind a UniFi Dream Machine Pro, which routes and firewalls
the network and peers with the cluster over BGP.

Cilium runs with `kubeProxyReplacement` and native routing, and advertises
LoadBalancer addresses to the gateway over BGP rather than announcing them on
the local segment. There are no L2 announcements: service addresses are routed,
so failover follows the routing table instead of gratuitous ARP, and the
addresses are reachable from anywhere the router will route to.

Those addresses come from a dedicated Services network rather than the client
network, which keeps cluster service addresses off the segment where laptops and
phones live and lets them carry their own firewall policy.

### DNS

Two ExternalDNS instances keep records in sync:

- **Private** — every route, synced to the gateway through the
  [ExternalDNS UniFi webhook](https://github.com/home-operations/external-dns-unifi-webhook).
- **Public** — only routes on the external Gateway, synced to Cloudflare.

The result is split-horizon DNS: at home, public hostnames resolve to LAN
addresses, so traffic to my own services never leaves the network.

## Key Paths

```text
.
├── bootstrap/          # One-time cluster bootstrap helpers
├── docs/               # ADRs, repo guidance, and operational notes
├── kubernetes/
│   ├── apps/           # Flux-managed applications, grouped by namespace
│   ├── components/     # Shared Kustomize components, SOPS, alerts, Kopiur
│   └── flux/cluster/   # Top-level Flux entrypoint used by render tooling
└── talos/              # Talos config templates and operator commands
```

Flux enters the cluster at `kubernetes/flux/cluster/ks.yaml`, then reconciles
the applications under `kubernetes/apps`.

## Automation / CI

Renovate manages dependency updates for charts, containers, GitHub Actions, and
other versioned references. Most updates use pull requests; selected low-risk
classes may branch-automerge.

Pull request checks and reviewers are:

| Check                | Status   | Purpose                                              |
| -------------------- | -------- | ---------------------------------------------------- |
| `Lint`               | Required | Checks workflow syntax, security, and file format.   |
| `Image Pull`         | Required | Finds image changes and pre-pulls them on the nodes. |
| `Konflate`           | Required | Renders manifests, posts diffs, and verifies images. |
| `Renovate PR Review` | Advisory | Reviews eligible Renovate PRs with Claude.           |

`Render` is a GitHub-hosted post-merge alarm that runs Flate against `main`
after changes under `kubernetes/`. It does not replace Konflate as the pull
request render and diff gate.

`Label Sync` keeps repository labels consistent.

See [Validation and Tooling](docs/guides/validation.md) for local validation commands and
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
diagnostics and Talos operations.

## Operations Docs

- [AI Workbench](docs/operations/ai-workbench.md) is a compact operator note
  for the Hermes and ToolHive workbench: current surface, boundaries, and the
  cluster-health triage loop.
- [Storage and Backups](docs/operations/storage-and-backups.md) describes the
  backup posture, the protected application set, and how to verify a restore.

## Thanks

This repository builds on patterns from
[onedr0p/home-ops](https://github.com/onedr0p/home-ops),
[buroa/k8s-gitops](https://github.com/buroa/k8s-gitops),
[bjw-s-labs/home-ops](https://github.com/bjw-s-labs/home-ops), and the
[Home Operations](https://discord.gg/home-operations) community.

[kubesearch.dev](https://kubesearch.dev/) is a great way to find examples of how
others deploy applications in similar clusters.

## License

See [LICENSE](./LICENSE).
