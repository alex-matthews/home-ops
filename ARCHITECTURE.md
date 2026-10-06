# Architecture

Verified 2026-10-05 against the repository at `main`; not against the live
cluster.

This repository describes a Kubernetes cluster running on Talos. Git holds
the intended configuration, and controllers turn it into running services.
Machine configuration, Kubernetes resources, external services and application
data have different sources of truth, owners and recovery paths. This
document explains those boundaries.

[AGENTS.md](AGENTS.md) owns working rules and task routing; the
[app guide](.agents/skills/add-app/references/app-pattern.md) covers
application wiring, and linked references own procedures. This describes
declared configuration, not evidence of live health or successful recovery.

## Layers and owners

| Layer                          | Source of truth                                           | Who applies changes                                                                                  | What Git alone cannot recover                                                                               |
| ------------------------------ | --------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Talos machine configuration    | Templates under [talos/](talos/README.md)                 | An operator renders and applies configuration; Tuppr resources request version upgrades              | The externally held credentials needed to render and apply it; editing a template changes no node by itself |
| Kubernetes resources           | `kubernetes/` on `main`                                   | Flux, continuously                                                                                   | Anything created interactively in the cluster                                                               |
| External services and hardware | Router, Cloudflare account and tunnel, 1Password, the NAS | Mixed: accounts and hardware are configured outside; controllers manage DNS records and certificates | Accounts, vault contents, NAS contents and records no controller manages                                    |
| Application data               | Volumes, databases, backup repositories                   | Workloads at runtime; backup controllers on schedule                                                 | Data never backed up, or whose repository is gone                                                           |
| Bootstrap-supplied credentials | Held by people, outside the cluster                       | Supplied by an operator during bootstrap                                                             | The credentials themselves                                                                                  |

## Machines and bootstrap

Talos supplies the operating system and the Kubernetes control plane. An
operator renders and applies the [machine configuration](talos/README.md)
from the templates in Git, using credentials held outside the repository.
Editing a template therefore changes no node until someone applies the
result, and a clone on its own is not enough to apply it again later. The
Tuppr resources that Flux manages request Talos and Kubernetes version
upgrades on the running nodes; they are not the path by which template edits
reach a machine.

On a new cluster nothing is yet running to install anything, so the
[bootstrap sequence](bootstrap/README.md) is operator-driven. It configures
the nodes, initialises etcd, applies base resources and CRDs, then uses
Helmfile to install the core charts, including flux-operator and
flux-instance. Flux Operator manages the Flux controllers through a
FluxInstance, and from that point Git drives the cluster. Bootstrap is a
one-off handover; reconciliation is the steady state.

## From a commit to a workload

The configured Flux instance follows `main`, entering at
`kubernetes/flux/cluster`. GitHub push events ask Flux to fetch a new
revision, with polling as a fallback. CI checks a change before merge and is
evidence for review; merging makes the change available, and the controllers
still have to process it. Flux applies declarations, Helm renders charts into
Kubernetes resources, and operators such as CloudNativePG and Rook-Ceph
fulfil the custom resources that describe their systems.

A compact view of the tree helps when reading what follows:

```text
kubernetes/
  flux/cluster/           entry point: the cluster-apps Kustomization
  apps/<namespace>/       namespace kustomization.yaml, one directory per app
    <app>/ks.yaml         the app's Flux Kustomization(s)
    <app>/app/            HelmRelease, routes, claims and other resources
  components/             reusable Kustomize Components, included by a
                          namespace or by an app
```

The entry directory declares
[cluster-apps](kubernetes/flux/cluster/ks.yaml), which selects
`kubernetes/apps`. Each namespace directory's `kustomization.yaml` gathers
its apps' Flux Kustomizations and may include shared components.

An app's effective configuration is assembled from four inputs, and only the
first lives in its own directory:

- **The app's own resources**, selected by its Flux Kustomization.
- **Components the app includes** through `spec.components`. These are
  reusable fragments under [kubernetes/components](kubernetes/components)
  that add resources and patches to whatever includes them.
  [Atuin](kubernetes/apps/default/atuin/ks.yaml) includes
  [kopiur](kubernetes/components/kopiur/kustomization.yaml), which
  contributes a protected PersistentVolumeClaim, local and remote backup
  policies and a Restore declaration. Apps select shared components
  explicitly; a selected component can include others in turn.
- **Components the namespace includes**, such as alerts and SOPS. These
  contribute resources to that namespace's build, and what they do depends
  on the resource and on what consumes it. An Alert carries event selectors
  that decide which reconciliations it reports. The SOPS component supplies
  encrypted substitution data, but an app receives those values only if its
  Kustomization opts into postBuild substitution. Namespace inclusion is
  not inheritance.
- **Parent patches from cluster-apps**, which give child Kustomizations
  decryption and retry settings and set install and upgrade policies on
  nested HelmReleases.

For anyone editing or reviewing, the consequence is that a HelmRelease
cannot be read in isolation, and a change to a shared component or parent
patch alters many consumers without touching their directories. The
[app guide](.agents/skills/add-app/references/app-pattern.md) owns how to include components and
how to wire a new app.

A runtime dependency between two services does not by itself make their
Flux Kustomizations depend on one another. The
[ordering rules](docs/policy/decisions.md#reconciliation-ordering) define
required operator dependencies and the exceptions where retries alone are
insufficient. Keeping the two
separate stops an outage in one service from blocking configuration changes
to the services that merely call it.

## What CI proves

CI is evidence for review, not proof that a change works in the cluster. The
`main` ruleset requires Lint, Konflate, Image Pull and Chart Verify's
Coverage job; everything else advises or alarms.

- **Lint** runs only for changed file classes: actionlint and zizmor on
  workflows, ShellCheck at warning level on shell scripts, and oxfmt on
  JSON, TOML, YAML and Markdown. It checks no links or prose.
- **Konflate**, hosted in the cluster, renders the pull request and posts the
  rendered diff. It is the pull request's render evidence, subject to
  completeness checks, and does not cover machine configuration or tooling.
- **Image Pull** compares images with Flate and pulls the changed ones on
  the cluster's own runners.
- **Chart Verify** has three jobs. Coverage, offline, enforces one verify
  block or exclusion per chart source and guards removals and identity
  changes; it proves declarations, not their truth. Signatures advises: it
  verifies changed keyless Cosign tag pins and skips other providers and
  digest-only pins. Fixtures runs the scripts' offline tests.
- **kritika** gives an advisory review of pull requests, Renovate's
  included, from inside the cluster. Classes that Renovate automerges can
  merge on the required checks before a review lands, and only because
  `.renovaterc.json5` sets `automergeType: "pr"`.

After merge, **Render** runs Flate on `main` as an unrequired alarm that is
silent unless watched; Flux's own alerts report failed applies. **Chart
Signing Watch** looks weekly for signing material on sources declared
unsigned and keeps one findings issue; a failed lookup is inconclusive, never
evidence of absence. None of these proves decryption, admission, runtime
health or restore success, and a bypass merge is governed by
[standing decisions](docs/policy/decisions.md#bypass-merges).

## Traffic, names and certificates

Cilium provides pod networking and replaces kube-proxy. It allocates
LoadBalancer addresses from a
[dedicated pool](kubernetes/apps/kube-system/cilium/app/networking.yaml) and
advertises routes for them to the network's router over BGP. L2
announcements are disabled. The pool sits outside the nodes' L2 subnet,
and no real interface holds its addresses. That combination is deliberate: a
host treats an address on its own subnet as on-link and resolves it with ARP
rather than sending it to its router, so a pool inside a shared subnet would
leave clients asking for addresses nothing answers for. Placed outside, a
client on the local network hands the packet to the router, which has
learned the route from Cilium.

The Kubernetes API is reached through a LoadBalancer address as well.
Bootstrap connects directly to a node until Cilium's networking
configuration makes that address reachable. The API hostname is a record
maintained separately on the router. The repository's mise environment
selects read-only Kubernetes and Talos identities by default, and
administrative identities are separate. The
[access guide](docs/operations/access.md) covers those identities;
[break-glass access](docs/recovery/break-glass.md) covers DNS or router failure.

Resolving names and maintaining records are different jobs. CoreDNS serves
service discovery inside the cluster. Outside it, two ExternalDNS instances
maintain records in the systems that answer queries. The instance with the
UniFi webhook
([unifi-dns](kubernetes/apps/network/unifi-dns/app/helmrelease.yaml)) keeps
local application records on the router, derived from HTTPRoutes and
Services, and a second instance
([cloudflare-dns](kubernetes/apps/network/cloudflare-dns/app/helmrelease.yaml))
keeps public records in Cloudflare. Neither answers DNS queries itself.

HTTPRoutes attach services to an internal or an external Envoy gateway.
Cloudflare Tunnel forwards public requests to the external gateway.
cert-manager obtains the gateways' wildcard
[certificate](kubernetes/apps/network/envoy-gateway/app/certificate.yaml)
from Let's Encrypt through a Cloudflare DNS-01
[issuer](kubernetes/apps/cert-manager/cert-manager/app/clusterissuer.yaml),
so TLS issuance depends on Cloudflare API access as well as on the cluster.
Routing decides how a request reaches a service and TLS protects the
connection; neither decides who may use the service. The
[public-surface guidance](docs/policy/public-surfaces.md) owns the
controls an exposed service needs.

## Configuration and credentials

Two distinct mechanisms carry sensitive values. The
[selection rules](docs/policy/decisions.md#secrets-and-substitution) say which to use.

Ordinary workload credentials come from 1Password. Connect makes them
available to External Secrets, which creates the Kubernetes Secrets that
workloads consume, whether as mounted files or as environment references.
Re-applying those declarations cannot recover a credential that no longer
exists in the vault.

Substitution data, such as domain values, is stored SOPS-encrypted in Git.
Flux decrypts it where the SOPS component is included, and an app must opt
into substitution to receive the values. This is configuration rather than
runtime credential delivery. The one sanctioned overlap is the exception for
encrypted, indivisible structured files, which the same selection rules
describe.

Both paths rest on material that an operator supplies during bootstrap.
Reconciliation does not generate its own access to 1Password, nor can it
decrypt SOPS data without the key material it was given. Those inputs are
prerequisites of the cluster, held outside it by people, not outputs of it.

## Persistent data and recovery

Rook-Ceph provides replicated block storage. OpenEBS provides node-local
volumes, including those PostgreSQL uses. Some applications also mount bulk
data from the external NAS. Replication keeps data available through node
and disk failures; it does not undo deletion. The Ceph storage class uses a
Delete reclaim policy, so removing a claim can destroy its volume.

Application-volume backup is opt-in through the kopiur component described
above. Its two backup policies are independent: the local policy writes
snapshots to Garage, an S3 service running on the external NAS outside
Kubernetes, and the remote policy reads the application volume again and
writes to Cloudflare R2. The remote repository is not a copy of the local
one, so each is a separate line of defence, and because Garage is outside
the cluster, rebuilding the cluster does not remove the local repository.

The component's Restore declaration selects the local policy and is
configured with `onMissingSnapshot: Fail`. A protected claim with no
snapshot in the local repository is therefore not populated, and the Restore
reports failure rather than quietly producing an empty volume. Protection
covers only the claim the component defines; additional claims and caches
belonging to the same app are not protected by association.

PostgreSQL follows a separate path. CloudNativePG archives base backups and
write-ahead logs to R2 through Barman, and the database manifest declares
recovery from that archive rather than initialisation of an empty database.
An empty archive blocks recovery. Data lost before it was archived is beyond
this path. The
[restore procedures](.agents/skills/restore-data/SKILL.md) cover both
mechanisms and how to verify what came back.

A rebuild therefore depends on more than this clone. Reconciliation can
recreate declared Kubernetes resources when their prerequisites are available.
It cannot recover lost NAS contents, missing backup repositories, human-held
credentials, unprotected volumes or a login set up interactively.
The [rebuild guide](bootstrap/README.md) gathers those
prerequisites and the checks that prove recovery succeeded.

## Seeing failures

Prometheus collects metrics and VictoriaLogs stores logs; Grafana queries
both. Prometheus alerts and selected Flux reconciliation events feed
Alertmanager. Together they surface three different kinds of failure: a Git
revision that has not been applied, a workload that is unhealthy, and an
application that is running but behaving incorrectly. The
[observability guide](docs/operations/observability.md) explains how to tell
them apart.

The monitoring stack runs inside the cluster it observes. Its history and
its non-declarative dashboard state are outside the backup set, so a rebuild
brings back the stack but not what it had seen. Healthy controllers after a
rebuild are one piece of recovery evidence; restored data and correct
application behaviour each need their own.
