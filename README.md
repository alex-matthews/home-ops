# My Home Operations Repository

_... managed with Flux, Renovate and GitHub Actions_ 🤖

---

## 📖 Overview

This repository contains the configuration for my home infrastructure and Kubernetes cluster. I try to follow Infrastructure as Code (IaC) and GitOps principles, using tools like [Talos Linux](https://www.talos.dev/), [Kubernetes](https://kubernetes.io/), [Flux](https://github.com/fluxcd/flux2), and [GitHub Actions](https://github.com/features/actions) to automate deployment and management.

---

## ⛵ Kubernetes

My Kubernetes cluster runs on [Talos Linux](https://www.talos.dev/), a minimal, security-hardened Linux distribution designed specifically for Kubernetes.

Persistent workloads utilise distributed block storage across the nodes, while a Synology NAS provides NFS and SMB shares for bulk file storage and backups.

### Core Components

- [actions-runner-controller](https://github.com/actions/actions-runner-controller): Manages self-hosted GitHub runners.
- [cert-manager](https://github.com/cert-manager/cert-manager): Automates the creation and management of TLS certificates.
- [cilium](https://github.com/cilium/cilium): Provides networking, security and observability for the cluster.
- [cloudflared](https://github.com/cloudflare/cloudflared): Enables secure ingress access via Cloudflare tunnels.
- [external-dns](https://github.com/kubernetes-sigs/external-dns): Syncs ingress DNS records to my UDM-Pro for internal services and to Cloudflare for public-facing services.
- [external-secrets](https://github.com/external-secrets/external-secrets): Manages Kubernetes secrets with the help of [1Password Connect](https://github.com/1Password/connect).
- [ingress-nginx](https://github.com/kubernetes/ingress-nginx): A Kubernetes ingress controller using NGINX as a reverse proxy and load balancer.
- [rook](https://github.com/rook/rook): Provides distributed block storage for persistent data.
- [volsync](https://github.com/backube/volsync): Automates backup and recovery of persistent volume claims (PVCs).

### GitOps and Automation

Flux continuously monitors the `kubernetes` directory in this repository, ensuring the cluster state remains in sync with the configuration stored in Git. Any changes pushed to the main branch are automatically applied by Flux controllers.

For continuous integration and deployment, I use [GitHub Actions](https://github.com/features/actions). One important workflow is [Renovate](https://github.com/renovatebot/renovate), which scans my entire repository for dependency updates and automatically creates detailed PRs, making it easy to review and merge changes.

---

## ☁️ Cloud Dependencies

I rely on a few cloud services for essential functionality:

| Service                                   | Purpose                                           | Cost        |
| ----------------------------------------- | ------------------------------------------------- | ----------- |
| [1Password](https://1password.com/)       | Secret management via External Secrets            | ~$65/year   |
| [Cloudflare](https://www.cloudflare.com/) | Domain management, R2, Workers                    | ~$40/year   |
| [GitHub](https://github.com/)             | Repository hosting and CI/CD                      | Free        |
| [Pushover](https://pushover.net/)         | Kubernetes alerts and app notifications           | $5 one-time |

---

## 🌐 DNS and Networking

My home network is managed by a [UniFi Dream Machine Pro](https://store.ui.com/us/en/category/cloud-gateways-large-scale/products/udm-pro), which functions as the router, firewall, and DNS server for all devices on my LAN.

My cluster runs two instances of [ExternalDNS](https://github.com/kubernetes-sigs/external-dns). One instance syncs private DNS records to my UDM-Pro via the [ExternalDNS webhook provider for UniFi](https://github.com/kashalls/external-dns-unifi-webhook), while the other syncs public DNS records to Cloudflare. This setup is controlled by specifying an ingress class: `internal` for private DNS and `external` for public DNS. Each external-dns instance then syncs records to the appropriate platform.

---

## 🤝 Acknowledgments

I’d like to thank the following resources and communities for their invaluable contributions:

- **[kubesearch.dev](https://kubesearch.dev/)** – An excellent resource for finding configuration examples for nearly any application I want to deploy in my cluster.
- **[onedr0p's cluster template](https://github.com/onedr0p/cluster-template)** – The foundation of this repository, thoughtfully designed with deep Flux integration.
- **[Home Operations Discord](https://discord.gg/home-operations)** – A welcoming community where I’ve gained valuable insights and continue to learn from others.
