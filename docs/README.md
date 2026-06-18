# Documentation

This directory contains durable project documentation for the home-ops
repository.

## Architecture Decisions

Architecture decision records live in [`adr/`](adr/). Use ADRs for decisions
that should explain why the repository, cluster, or operating model is shaped a
certain way.

- [ADR-0001: AI Home-Ops Workbench](adr/0001-ai-home-ops-workbench.md)

## Guides

Contributor, agent, and repository usage guides live in [`guides/`](guides/).

- [Repo Guide](guides/repo-guide.md)

## Operations

Operational posture, runbooks, migration notes, and current-state documents live
in [`operations/`](operations/).

- [AI Workbench Prompts](operations/ai-workbench.md)
- [Storage and Backups](operations/storage-and-backups.md)

## Placement Rule

Use this split when adding documents:

| Question                                                                                   | Location      |
| ------------------------------------------------------------------------------------------ | ------------- |
| Does this explain why the repository, cluster, or operating model is shaped a certain way? | `adr/`        |
| Does this explain how to work in this repository or use its tooling?                       | `guides/`     |
| Does this explain how the live cluster is operated, restored, migrated, or understood?     | `operations/` |
