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
applications under `kubernetes/apps` from `main`. The household gets media and a
few services out of it. I get a production system small enough to understand
completely and real enough to break, and a place to practise the design and
operation of cloud-native platforms.

Disaster recovery is built in. Wipe all three nodes and one command brings the
cluster back from this repository and its own backups. I have done that in
production, deliberately, and
[Cluster Rebuild](docs/operations/cluster-rebuild.md) records what it took.

## How a change lands

Changes under `kubernetes/` arrive as pull requests, and Flux applies `main`
once they merge. Renovate opens dependency updates for charts, containers,
GitHub Actions, and the pinned toolchain. A few low-risk classes merge on their
own once the required checks pass.

Two guards on that path are this repository's own design. Flux verifies chart
sources against the identity that signs them wherever a publisher's signature
can be pinned to one. A tag bump signed by anyone else freezes that chart at
its last verified revision.
[ADR-0003](docs/adr/0003-helm-chart-source-verification.md) sets the trust
classes and records what stays excluded. Renovate pull requests
under `kubernetes/` also get a reviewer. It reads the manifests the upgrade
renders, which release notes do not show, alongside the upstream chart source,
and posts one advisory comment. It has flagged a good number of upgrades for a
human look, including a default-on `FlowSchema` that the release notes did not
mention.

| Check                | Status   | Purpose                                                                        |
| -------------------- | -------- | ------------------------------------------------------------------------------ |
| `Lint`               | Required | Checks workflow syntax, security, and file format.                             |
| `Image Pull`         | Required | Finds image changes and pulls them on a cluster runner.                        |
| `Konflate`           | Required | Renders manifests, posts the diff, and verifies images exist.                  |
| `Chart Verify`       | Advisory | Re-verifies changed chart sources and flags a dropped or changed verify block. |
| `Renovate PR Review` | Advisory | Reads the rendered diff and the upstream chart source with Claude.             |

See [Validation and Tooling](docs/guides/validation.md) for what each check
proves and what it cannot.

## Platform

| Layer             | Role                                                                                                                                                                                                                                                                                                                                    |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Compute           | Three Intel NUC 11 Pro i5 nodes, all in the control plane, each with 64 GiB RAM, a 500 GB SATA SSD for system and scratch storage, and a 1 TB NVMe disk for Ceph                                                                                                                                                                        |
| Operating system  | [Talos Linux](https://www.talos.dev/), upgraded in place by [tuppr](https://github.com/home-operations/tuppr)                                                                                                                                                                                                                           |
| Delivery          | [Flux](https://fluxcd.io/), installed and kept current by [Flux Operator](https://github.com/controlplaneio-fluxcd/flux-operator)                                                                                                                                                                                                       |
| Networking        | [Cilium](https://github.com/cilium/cilium) for the pod network and service addresses, [Envoy Gateway](https://github.com/envoyproxy/gateway) for HTTP routes, and [cloudflared](https://github.com/cloudflare/cloudflared), a Cloudflare Tunnel that admits Internet traffic to the external Gateway with no inbound port opened for it |
| DNS               | [ExternalDNS](https://github.com/kubernetes-sigs/external-dns) writing records to UniFi for the LAN and to Cloudflare for the Internet                                                                                                                                                                                                  |
| Secrets           | Runtime credentials from [1Password Connect](https://1password.com/) through [External Secrets](https://github.com/external-secrets/external-secrets). Build-time substitutions from [SOPS](https://github.com/getsops/sops)-encrypted files in Git.                                                                                    |
| Application state | [Rook-Ceph](https://github.com/rook/rook) block storage, replicated across the three nodes                                                                                                                                                                                                                                              |
| Bulk media        | Synology NAS over NFS                                                                                                                                                                                                                                                                                                                   |
| CI workspaces     | [OpenEBS](https://github.com/openebs/openebs) host-local volumes                                                                                                                                                                                                                                                                        |
| Backups           | [Kopiur](https://github.com/home-operations/kopiur) to two independent repositories, Garage S3 locally and Cloudflare R2 off-site                                                                                                                                                                                                       |
| Observability     | [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts) for metrics and alerts, VictoriaLogs for logs, [Grafana](https://github.com/grafana/grafana) for dashboards, and [Gatus](https://github.com/TwiN/gatus) for endpoint checks                                                                                |
| Automation        | [Renovate](https://github.com/renovatebot/renovate) for dependency updates, [GitHub Actions](https://github.com/features/actions) for the pull request checks above, and [Konflate](https://github.com/home-operations/konflate) for rendered diffs                                                                                     |
| AI workbench      | [Hermes](https://github.com/NousResearch/hermes-agent) with [ToolHive](https://github.com/stacklok/toolhive): an in-cluster assistant with read-only tools for Flux, GitHub, Grafana, and Konflate                                                                                                                                      |

## Networking

The cluster sits behind a UniFi Dream Machine Pro, which routes and firewalls
the network.

Cilium runs with `kubeProxyReplacement` and native routing, with no L2
announcements. LoadBalancer addresses come from a dedicated range that no node
holds an interface on; the nodes advertise routes to it over BGP, so all
traffic to those addresses goes through the gateway.

Internet traffic reaches the external Gateway only through a Cloudflare Tunnel.
Every service exposed that way has a row in the
[public surfaces register](docs/operations/public-surfaces.md), which records
who consumes it, whether it changes state, and what stands in front of it.

Two ExternalDNS instances write the records, every route to UniFi through the
[UniFi webhook](https://github.com/home-operations/external-dns-unifi-webhook)
and only the external Gateway's routes to Cloudflare, so at home a public
hostname resolves to its LAN address and traffic to my own services never
leaves the network.

## Local workflow

To work in the repository, install the pinned toolchain and list the operator
recipes:

```sh
mise install
just -l
```

`.mise/config.toml` pins the toolchain, checksum-verified against the committed
`.mise/mise.lock`. `just` carries the recipes for bootstrap, cluster
diagnostics, and Talos operations. Credential files such as `age.key`,
`kubeconfig`, and `talosconfig` are ignored by Git.

> [!IMPORTANT]
> The default environment carries read-only Kubernetes and Talos identities,
> and a mise hook mints the Kubernetes token fresh each sitting.
> `MISE_ENV=admin` selects the administrative ones, so writing to the cluster
> is a deliberate step.

## Repository layout

```text
.
├── bootstrap/          # Helmfile and recipes for a cold start
├── docs/               # Guides, operations notes, and ADRs
├── kubernetes/
│   ├── apps/           # Flux-managed applications, one directory per namespace
│   ├── components/     # Kustomize components an app opts into: alerts,
│   │                   # dragonfly, kopiur, sops, zeroscaler
│   └── flux/cluster/   # The root Kustomization Flux applies from main
└── talos/              # Machine config templates and node recipes
```

## Where it is going

Research comes first, then issues, then a decision record wherever a change
touches how the cluster is run. The next stretch is security as one design I
can explain end to end. Inside that sit network policy that holds within the
cluster as well as at its edges, and one identity across the applications, the
operator tooling, and the agents that help operate it. Alongside it, I want
the in-cluster assistant to watch the cluster, report what it finds, and in
time propose fixes for a human to review. The hardware I keep circling is a
10 GbE core, enterprise disks in the NUCs, and a node built for inference.

## Reading further

The documentation is indexed in [docs/README.md](docs/README.md). Four to
start with:

- [Cluster Model](docs/guides/cluster-model.md) for how a merged change reaches
  the cluster and what waits for what.
- [Storage and Backups](docs/operations/storage-and-backups.md) for the backup
  posture and how a restore is verified.
- [Cluster Rebuild](docs/operations/cluster-rebuild.md) for what a full teardown
  and rebuild involves.
- [AI Workbench](docs/operations/ai-workbench.md) for what the in-cluster
  assistant can reach.

The larger decisions are in [docs/adr](docs/adr/) with the options they
rejected, and the smaller ones are in issues. Rules for agents working in this
repository are in [AGENTS.md](AGENTS.md).

## Thanks

This repository builds on patterns from
[onedr0p/home-ops](https://github.com/onedr0p/home-ops),
[buroa/home-ops](https://github.com/buroa/home-ops),
[bjw-s-labs/home-ops](https://github.com/bjw-s-labs/home-ops), and the
[Home Operations](https://discord.gg/home-operations) community.

## License

MIT, see [LICENSE](./LICENSE). The repository began from
[onedr0p's cluster-template](https://github.com/onedr0p/cluster-template), and
the parts that derive from it carry onedr0p's notice in [NOTICE](./NOTICE).
