# Documentation

This directory contains durable project documentation for the home-ops
repository. Keep scratch notes, raw agent transcripts, and one-off prompt
experiments out of this tree.

## Map

| Need                                          | Read or update                                                       |
| --------------------------------------------- | -------------------------------------------------------------------- |
| Understand repo layout, validation, and peers | [Repo Guide](guides/repo-guide.md)                                   |
| Understand the AI workbench architecture      | [ADR-0001: AI Home-Ops Workbench](adr/0001-ai-home-ops-workbench.md) |
| Operate or test the Hermes/ToolHive workbench | [AI Workbench](operations/ai-workbench.md)                           |
| Understand backup posture or Kopiur migration | [Storage and Backups](operations/storage-and-backups.md)             |

## Placement Rule

- `adr/`: why the repository, cluster, or operating model is shaped a certain
  way.
- `guides/`: how to work in this repository or use its tooling.
- `operations/`: how the live cluster is operated, restored, migrated, or
  understood.
