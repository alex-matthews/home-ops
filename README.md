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

This repository is the source of truth for my home Kubernetes cluster: three
Intel NUCs running Talos Linux, with Flux reconciling applications from `main`.
The cluster runs the household's media and services, and gives me somewhere
to practise designing and operating cloud-native systems.

## Platform

| Layer            | Role                                                                                                                                                                                                                                                                                                                                                         |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Compute          | Three Intel NUC 11 Pro i5 nodes, each with 64 GiB RAM, a 500 GB SATA SSD and a 1 TB NVMe disk for Ceph                                                                                                                                                                                                                                                       |
| Operating system | [Talos Linux](https://www.talos.dev/), upgraded by [tuppr](https://github.com/home-operations/tuppr)                                                                                                                                                                                                                                                         |
| Delivery         | [Flux](https://fluxcd.io/) and [Flux Operator](https://github.com/controlplaneio-fluxcd/flux-operator); [Renovate](https://github.com/renovatebot/renovate) proposes updates; on pull requests, [Konflate](https://github.com/home-operations/konflate) posts the rendered diff and [kritika](https://github.com/home-operations/kritika) reviews the change |
| Networking       | [Cilium](https://github.com/cilium/cilium), [Envoy Gateway](https://github.com/envoyproxy/gateway) and Cloudflare Tunnel; [ExternalDNS](https://github.com/kubernetes-sigs/external-dns) manages LAN and public DNS                                                                                                                                          |
| Secrets          | [External Secrets](https://github.com/external-secrets/external-secrets) with 1Password Connect; [SOPS](https://github.com/getsops/sops) for encrypted configuration in Git                                                                                                                                                                                  |
| Storage          | [Rook-Ceph](https://github.com/rook/rook) for app volumes; [OpenEBS](https://github.com/openebs/openebs) for PostgreSQL and CI workspaces; Synology NFS for bulk media                                                                                                                                                                                       |
| Database         | Shared PostgreSQL managed by [CloudNativePG](https://github.com/cloudnative-pg/cloudnative-pg)                                                                                                                                                                                                                                                               |
| Backups          | App volumes: [Kopiur](https://github.com/home-operations/kopiur) to independent Garage S3 and Cloudflare R2 repositories. PostgreSQL: Barman Cloud to R2                                                                                                                                                                                                     |
| Observability    | Prometheus, VictoriaLogs, Grafana and Gatus                                                                                                                                                                                                                                                                                                                  |
| AI workbench     | [Hermes](https://github.com/NousResearch/hermes-agent) with [ToolHive](https://github.com/stacklok/toolhive) for read-only cluster and repository tools                                                                                                                                                                                                      |

## Local workflow

From the repository root, install the pinned tools with
[mise](https://mise.jdx.dev/getting-started.html), then list the operator
recipes:

```bash
mise install
just -l
```

> [!IMPORTANT]
> The default environment uses read-only Kubernetes and Talos identities, and
> a mise hook refreshes the Kubernetes token when needed. Set `MISE_ENV=admin`
> to select the administrative identities for an operator session.

## Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md): how the system fits together.
- [docs/README.md](docs/README.md): the index of policy, operations and recovery
  documents.
- [bootstrap/README.md](bootstrap/README.md): a full rebuild.
- [CONTRIBUTING.md](CONTRIBUTING.md): validating and writing changes.
- [AGENTS.md](AGENTS.md): repository rules and task guidance.

## Thanks

This repository builds on patterns from
[onedr0p/home-ops](https://github.com/onedr0p/home-ops),
[buroa/home-ops](https://github.com/buroa/home-ops),
[bjw-s-labs/home-ops](https://github.com/bjw-s-labs/home-ops), and the
[Home Operations](https://discord.gg/home-operations) community.

## License

MIT; see [LICENSE](LICENSE). The repository began from
[onedr0p's cluster-template](https://github.com/onedr0p/cluster-template), and
the parts derived from it carry onedr0p's notice in [NOTICE](NOTICE).
