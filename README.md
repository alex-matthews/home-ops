<div align="center">

<img src="https://raw.githubusercontent.com/onedr0p/home-ops/main/docs/src/assets/logo.png" align="center" width="144px" height="144px"/>

### My Homelab Repository :octocat:

_... automated via [Flux](https://fluxcd.io), [Renovate](https://github.com/renovatebot/renovate) and [GitHub Actions](https://github.com/features/actions)_ :robot:

</div>

---

## 📖 Overview

This is a mono repository for my home Kubernetes cluster. Both multi-cluster and multi-site are coming soon.

## To do

[] (gh) create a custom bot for renovate and make email notifications less noisy
[] (pi) Deploy `external-secrets`
[] (nas) Deploy `minio`
[] (pi) Deploy `longhorn` and `volsync`
[] (infra @ site 1) Segment home network - create separate vlans etc
[] (infra @ site 2) Upgrade network infrastructure (router, PoE switch, access point/s); migrate pi-cluster to site 2 but have it utilise the site 1 NAS if possible - else get a second NAS
[] (pi) Deploy `home-assistant` and related apps/services
[] (gh) Refactor repo to support multiple clusters ('main' and 'pi')
[] (template @ site 1) Provision AMD64 machines with Talos Linux and call this cluster 'main'
[] (main) Deploy `external-secrets`
[] (main) Deploy persistent storage (`rook-ceph`, `volsync`)
[] (main) Deploy observability apps (`kube-prometheus-stack`, `grafana`, `gatus` etc)
[] (pi) Deploy observability apps (`kube-prometheus-stack`, `gatus` etc)
[] (all) Deploy `tailscale-operator` and define misc ingresses
[] (main) Deploy `cloudnative-pg` and `dragonfly`
[] (main) Deploy and configure a robust downloads/media stack
[] (main) Deploy `authelia/glauth` or `authentik`
[] (all) Persist SSL certs through a pushsecret - see Devin's repo
[] (infra/gh) Introduce Terraform? (Cloudflare, MinIO, Authentik etc)
