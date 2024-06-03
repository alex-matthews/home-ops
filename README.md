<div align="center">

<img src="https://raw.githubusercontent.com/onedr0p/home-ops/main/docs/src/assets/logo.png" align="center" width="144px" height="144px"/>

### My Homelab Repository :octocat:

_... automated via [Flux](https://fluxcd.io), [Renovate](https://github.com/renovatebot/renovate) and [GitHub Actions](https://github.com/features/actions)_ :robot:

</div>

---

## 📖 Overview

This is a mono repository for my home Kubernetes cluster. Multi-cluster and multi-site coming soon™️

## To do

- [ ] (gh) Create a custom bot for Renovate and make email notifications less noisy
- [ ] (pi-cluster) Deploy `external-secrets`
- [ ] (nas) Deploy `minio`
- [ ] (pi-cluster) Deploy persistent storage (`longhorn`, `volsync`)
- [ ] (infra @ site 1) Segment home network - create separate vlans etc
- [ ] (infra @ site 2) Upgrade network infrastructure (router, PoE switch, access point/s); migrate pi-cluster
- [ ] (pi-cluster) Deploy `home-assistant` and related apps/services
- [ ] (gh) Refactor repo to support multi-cluster
- [ ] (infra @ site 1) Provision AMD64 machines with Talos Linux
- [ ] (main-cluster) Deploy `external-secrets`
- [ ] (main-cluster) Deploy persistent storage (`rook-ceph`, `volsync`)
- [ ] (main-cluster) Deploy observability apps (`kube-prometheus-stack`, `grafana`, `gatus` etc)
- [ ] (pi-cluster) Deploy observability apps (`kube-prometheus-stack`, `gatus` etc)
- [ ] (all) Deploy `tailscale-operator` and define ingresses/endpoints
- [ ] (main-cluster) Deploy `cloudnative-pg` and `dragonfly`
- [ ] (main-cluster) Deploy and configure a robust downloads/media stack
- [ ] (main-cluster) Deploy `authelia/glauth` or `authentik`
