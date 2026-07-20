# Documentation

This directory contains durable project documentation for the home-ops
repository. Keep scratch notes, raw agent transcripts, and one-off prompt
experiments out of this tree.

## Map

| Need                                           | Read or update                                                                       |
| ---------------------------------------------- | ------------------------------------------------------------------------------------ |
| Understand repo layout, validation, and peers  | [Repo Guide](guides/repo-guide.md)                                                   |
| Understand the AI workbench architecture       | [ADR-0001: AI Home-Ops Workbench](adr/0001-ai-home-ops-workbench.md)                 |
| Understand the backup storage decisions        | [ADR-0002: Kopiur Backend and Remote Shape](adr/0002-kopiur-backup-storage-shape.md) |
| Operate or test the Hermes/ToolHive workbench  | [AI Workbench](operations/ai-workbench.md)                                           |
| Understand backup posture or Kopiur migration  | [Storage and Backups](operations/storage-and-backups.md)                             |
| Renew or replace appliance management TLS      | [Appliance TLS](operations/appliance-tls.md)                                         |
| Reach the cluster when DNS or the router fails | [Talos Access and Break-Glass](operations/talos-access-and-break-glass.md)           |

## Placement Rule

- `adr/`: why the repository, cluster, or operating model is shaped a certain
  way.
- `guides/`: how to work in this repository or use its tooling.
- `operations/`: how the live cluster is operated, restored, migrated, or
  understood.
