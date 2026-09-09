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
Intel NUC 11 Pro nodes running Talos Linux, with Flux reconciling the
applications under `kubernetes/apps` from `main`. It runs the household's
media — Plex and the services around it — and is where I work on the problems
I find most interesting: trust in what the cluster runs, and how far an AI
agent can be let into operating it without being handed the keys.

## Platform

| Layer             | Role                                                                                                                                                                                           |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Operating system  | [Talos Linux](https://www.talos.dev/), configured from templates under `talos/`                                                                                                                |
| Delivery          | [Flux](https://fluxcd.io/) under [Flux Operator](https://github.com/controlplaneio-fluxcd/flux-operator)                                                                                       |
| Networking        | [Cilium](https://github.com/cilium/cilium), [Envoy Gateway](https://github.com/envoyproxy/gateway), and [cloudflared](https://github.com/cloudflare/cloudflared)                               |
| DNS               | [ExternalDNS](https://github.com/kubernetes-sigs/external-dns) against Cloudflare and UniFi                                                                                                    |
| Secrets           | [External Secrets](https://github.com/external-secrets/external-secrets) with [1Password Connect](https://1password.com/); [SOPS](https://github.com/getsops/sops) for values committed to Git |
| Application state | [Rook-Ceph](https://github.com/rook/rook) block storage, replicated across the three nodes                                                                                                     |
| Bulk media        | Synology NAS over NFS                                                                                                                                                                          |
| CI workspaces     | [OpenEBS](https://github.com/openebs/openebs) host-local volumes                                                                                                                               |
| Backups           | [Kopiur](https://github.com/home-operations/kopiur) to a local Garage S3 repository and an independent Cloudflare R2 one                                                                       |
| Observability     | [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts), [Grafana](https://github.com/grafana/grafana), VictoriaLogs, and [Gatus](https://github.com/TwiN/gatus)          |
| Automation        | [Renovate](https://github.com/renovatebot/renovate), [GitHub Actions](https://github.com/features/actions), and [Konflate](https://github.com/home-operations/konflate)                        |
| AI workbench      | Hermes and ToolHive, with read-only tools for the cluster and this repository                                                                                                                  |

### Hardware

The cluster runs on three Intel NUC 11 Pro i5 nodes. Each node has 64 GiB RAM,
a 500 GB SATA SSD for system and scratch storage, and a dedicated 1 TB NVMe disk
for the replicated Ceph pool.

## Networking

The cluster sits behind a UniFi Dream Machine Pro, which routes and firewalls
the network.

Cilium runs with `kubeProxyReplacement` and native routing, with no L2
announcements. LoadBalancer addresses come from a dedicated range that no node
holds an interface on; the nodes advertise routes to it over BGP, so all
traffic to services goes through the gateway.

Internet traffic reaches the external Gateway only through a Cloudflare tunnel,
and every service exposed that way has a row in the
[public surfaces register](docs/operations/public-surfaces.md), which records
who consumes it, whether it changes state, and what stands in front of it. The
pull request that exposes a service is the one that adds the row.

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

## Automation / CI

Renovate opens dependency updates for charts, containers, GitHub Actions, and
the pinned toolchain, and a few low-risk classes merge on their own once the
required checks pass. Chart sources are verified against the identity that
signs them wherever a publisher's signature can be pinned to one. A tag bump
signed by anyone else freezes that chart at its last verified revision.
[ADR-0003](docs/adr/0003-helm-chart-source-verification.md) sets the trust
classes and records what stays excluded.

| Check                | Status   | Purpose                                                            |
| -------------------- | -------- | ------------------------------------------------------------------ |
| `Lint`               | Required | Checks workflow syntax, security, and file format.                 |
| `Image Pull`         | Required | Finds image changes and pulls them on a cluster runner.            |
| `Konflate`           | Required | Renders manifests, posts the diff, and verifies images exist.      |
| `Chart Verify`       | Advisory | Re-verifies changed chart sources and flags dropped verify blocks. |
| `Renovate PR Review` | Advisory | Reads the rendered diff and the upstream chart source with Claude. |

`Render` runs Flate, the local render tool, against `main` after a merge;
Konflate remains the pull request render and diff gate. See
[Validation and Tooling](docs/guides/validation.md) for what each check proves
and what it cannot.

## Local Workflow

`.mise/config.toml` pins the toolchain, checksum-verified against the committed
`.mise/mise.lock`. The default environment carries read-only Kubernetes and
Talos identities, and a mise hook mints the Kubernetes token fresh each sitting.
`MISE_ENV=admin` selects the administrative ones, so writing to the cluster is a
deliberate step. Credential files such as `age.key`, `kubeconfig`, and
`talosconfig` are ignored by Git.

```sh
mise install
just -l
```

`just` carries the operator recipes: bootstrap, cluster diagnostics, and Talos
operations.

## Where it is going

The next stretch of work is on trust and access: one identity across the
services, the operator tooling, and the AI clients; network policy that
contains traffic inside the cluster as well as at its edges; and carrying the
artifact-trust model from chart signatures through to image provenance. Behind
that sit power and cold-recovery hardening on the nodes, and a node for local
inference. The hardware I keep circling is a 10 GbE core, encryption at rest,
Secure Boot, and enterprise disks in the NUCs.

## Reading Further

The documentation is indexed in [docs/README.md](docs/README.md). Most
visitors want one of these first:

- [Cluster Model](docs/guides/cluster-model.md) for how a merged change reaches
  the cluster and what waits for what.
- [Storage and Backups](docs/operations/storage-and-backups.md) for the backup
  posture and how a restore is verified.
- [Cluster Rebuild](docs/operations/cluster-rebuild.md) for what a full teardown
  and rebuild involves.
- [AI Workbench](docs/operations/ai-workbench.md) for what the agent can see
  and do.

Rules for agents working in this repository are in [AGENTS.md](AGENTS.md).

## Thanks

This repository builds on patterns from
[onedr0p/home-ops](https://github.com/onedr0p/home-ops),
[buroa/home-ops](https://github.com/buroa/home-ops),
[bjw-s-labs/home-ops](https://github.com/bjw-s-labs/home-ops), and the
[Home Operations](https://discord.gg/home-operations) community.

[kubesearch.dev](https://kubesearch.dev/) is a great way to find examples of how
others deploy applications in similar clusters.

## License

See [LICENSE](./LICENSE).
