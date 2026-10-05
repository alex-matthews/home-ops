# Documentation

Start with [ARCHITECTURE.md](../ARCHITECTURE.md), then the leaf for the task.
Agents route through the [AGENTS task
router](../AGENTS.md#find-the-document-for-the-task); this page is the index
for people browsing. Keep scratch notes and transcripts outside this tree.

## Index

- [CONTRIBUTING.md](../CONTRIBUTING.md): validate locally, write for the
  record, keep documents true.
- [peers.md](peers.md): the peer cluster catalogue.
- `policy/`: standing decisions.
    - [decisions.md](policy/decisions.md): chart trust and exclusions,
      reconciliation ordering and dependency edges, secrets, data protection,
      PostgreSQL and the kritika database exception, workbench, appliance
      certificates, bypass merges.
    - [public-surfaces.md](policy/public-surfaces.md): what is exposed, to
      whom, behind which control.
- `operations/`: keeping a running cluster healthy.
    - [access.md](operations/access.md): identities and command selection.
    - [observability.md](operations/observability.md): metrics, logs, alerts
      and silences.
    - [backups.md](operations/backups.md): coverage, maintenance and health.
    - [workbench.md](operations/workbench.md): the AI workbench, its checks
      and its login.
    - [appliances.md](operations/appliances.md): router and NAS management
      certificates.
- `recovery/`: getting something back that has failed.
    - [break-glass.md](recovery/break-glass.md): reaching the cluster when DNS
      or the router fails.
    - [node-boot.md](recovery/node-boot.md): a node that will not boot, and
      firmware.

Procedures live beside the skills that use them, and machine guidance beside
its source:

- Data recovery: [application
  volumes](../.agents/skills/restore-data/references/app-volumes.md) and
  [PostgreSQL](../.agents/skills/restore-data/references/postgresql.md);
  a whole cluster follows [bootstrap](../bootstrap/README.md).
- [Node upgrades](../.agents/skills/upgrade-nodes/references/node-upgrades.md),
  including failed upgrades and reboots.
- [App pattern](../.agents/skills/add-app/references/app-pattern.md) and the
  [maintenance window](../.agents/skills/maintenance-window/SKILL.md).
- [Talos machine configuration](../talos/README.md).

## Retired Documents

Use each recorded commit and path for offline retrieval: search with
`git grep -n -e '<phrase>' <sha> -- docs .agents/skills` and read with
`git show <sha>:<path>`.

| Path                                                        | Last commit containing it | Replaced by                                                                                                                       |
| ----------------------------------------------------------- | ------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `docs/guides/pr-and-issue-writing.md`                       | `0becf529`                | [writing](../CONTRIBUTING.md#write-for-the-record)                                                                                |
| `docs/guides/writing-style.md`                              | `0becf529`                | [writing](../CONTRIBUTING.md#write-for-the-record)                                                                                |
| `.agents/skills/github-prose/SKILL.md`                      | `0becf529`                | [writing](../CONTRIBUTING.md#write-for-the-record)                                                                                |
| `.agents/skills/github-prose/references/issue-shapes.md`    | `0becf529`                | [writing](../CONTRIBUTING.md#write-for-the-record)                                                                                |
| `.agents/skills/github-prose/references/pr-shapes.md`       | `0becf529`                | [writing](../CONTRIBUTING.md#write-for-the-record)                                                                                |
| `.agents/skills/github-prose/references/review-contract.md` | `0becf529`                | [evidence and review](../CONTRIBUTING.md#evidence-and-review)                                                                     |
| `.agents/skills/github-prose/references/editor-briefs.md`   | `0becf529`                | retired without replacement                                                                                                       |
| `docs/adr/0001-ai-home-ops-workbench.md`                    | `beb4f457`                | [workbench policy](policy/decisions.md#workbench-and-automation), [workbench](operations/workbench.md)                            |
| `docs/adr/0002-kopiur-backup-storage-shape.md`              | `beb4f457`                | [data protection](policy/decisions.md#data-protection)                                                                            |
| `docs/adr/0003-helm-chart-source-verification.md`           | `beb4f457`                | [chart trust](policy/decisions.md#chart-trust)                                                                                    |
| `docs/adr/0004-public-surface-controls.md`                  | `beb4f457`                | [public surfaces](policy/public-surfaces.md)                                                                                      |
| `docs/adr/0005-cnpg-postgres.md`                            | `beb4f457`                | [PostgreSQL policy](policy/decisions.md#postgresql), [restore procedure](../.agents/skills/restore-data/references/postgresql.md) |
| `docs/guides/app-pattern.md`                                | `beb4f457`                | [app pattern](../.agents/skills/add-app/references/app-pattern.md)                                                                |
| `docs/guides/cluster-model.md`                              | `beb4f457`                | [architecture](../ARCHITECTURE.md), [reconciliation ordering](policy/decisions.md#reconciliation-ordering)                        |
| `docs/guides/peers.md`                                      | `beb4f457`                | [peers](peers.md)                                                                                                                 |
| `docs/guides/validation.md`                                 | `beb4f457`                | [validate locally](../CONTRIBUTING.md#validate-locally), [what CI proves](../ARCHITECTURE.md#what-ci-proves)                      |
| `docs/guides/writing-shapes.md`                             | `beb4f457`                | [writing](../CONTRIBUTING.md#write-for-the-record)                                                                                |
| `docs/guides/writing.md`                                    | `beb4f457`                | [writing](../CONTRIBUTING.md#write-for-the-record)                                                                                |
| `docs/guides/yaml-ordering.md`                              | `beb4f457`                | [YAML ordering](../.agents/skills/add-app/references/app-pattern.md#yaml-ordering)                                                |
| `docs/operations/ai-workbench.md`                           | `beb4f457`                | [workbench](operations/workbench.md)                                                                                              |
| `docs/operations/appliance-tls.md`                          | `beb4f457`                | [appliances](operations/appliances.md)                                                                                            |
| `docs/operations/cluster-rebuild.md`                        | `beb4f457`                | [bootstrap and rebuild](../bootstrap/README.md)                                                                                   |
| `docs/operations/node-firmware-and-boot.md`                 | `beb4f457`                | [node boot](recovery/node-boot.md)                                                                                                |
| `docs/operations/node-upgrades.md`                          | `beb4f457`                | [node upgrades](../.agents/skills/upgrade-nodes/references/node-upgrades.md)                                                      |
| `docs/operations/observability.md`                          | `beb4f457`                | [observability](operations/observability.md), rewritten at the same path                                                          |
| `docs/operations/public-surfaces.md`                        | `beb4f457`                | [public surfaces](policy/public-surfaces.md)                                                                                      |
| `docs/operations/storage-and-backups.md`                    | `beb4f457`                | [backups](operations/backups.md), [restore-data](../.agents/skills/restore-data/SKILL.md)                                         |
| `docs/operations/talos-access-and-break-glass.md`           | `beb4f457`                | [access](operations/access.md), [break-glass](recovery/break-glass.md)                                                            |
| `talos/README.md`                                           | `beb4f457`                | [Talos](../talos/README.md), rewritten at the same path                                                                           |
