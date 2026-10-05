# Contributing

Verified 2026-10-05 against the repository at `main`.

Read [ARCHITECTURE.md](ARCHITECTURE.md) first; it also says what CI proves.
Agents follow [AGENTS.md](AGENTS.md) for boundaries and routing. Compare with
other clusters through the [peers catalogue](docs/peers.md).

## Validate locally

Choose the smallest matching checks, read their output and report their limits.

App changes need a Kustomize build and Flate checks; add image comparison
when images may change. Workflow/tooling changes need formatting, workflow
checks and inspection of affected Actions logic. Storage changes need the
[restore evidence](.agents/skills/restore-data/SKILL.md) relevant to their
risk. Docs need formatting, plus verification of changed commands/procedures.

Use pinned tools. Keep `test all` full-tree: adding `--base` selects
changed-only mode. For image comparison, replace `main` with the reviewed base:

```bash
mise exec --no-deps -- oxfmt --check . '!**/*.sops.yaml' '!**/*.sops.yml'
mise exec --no-deps -- actionlint
mise exec --no-deps -- zizmor --offline .github/workflows
mise exec --no-deps -- shellcheck -S warning $(git ls-files '*.sh' '.github/tests/chart-signing/bin/_fake')
.github/tests/chart-signing/run.sh
mise exec -- kubectl kustomize kubernetes/apps/<namespace>/<app>/app
mise exec -- flate test all -p ./kubernetes/flux/cluster --allow-missing-secrets
mise exec -- flate diff images -p ./kubernetes/flux/cluster --base main -o json
```

Flate 0.6.5 base comparisons reject `worktreeConfig`. Use a standalone clone
containing the candidate changes, preserving repository settings.

### What a local render proves

Flate 0.6.5 renders the working tree with offline substitution. Missing live
values can be empty; SOPS values are placeholders. `--allow-missing-secrets`
can skip sources/consumers; output omits Secrets and CRDs by default. Inspect
objects, base and warnings: success proves neither signatures, decryption,
admission nor health
([source and limits](https://redirect.github.com/home-operations/flate/blob/631b76b69c4e58c6f4d1cb01e23616fa61aebafa/README.md#behaviors)).

Server dry-run tests admission, not runtime success. Follow
[access](docs/operations/access.md): verify tunnel/response success and select
an existing administrative identity when needed.

### Reviewing upgrades

Inspect chart templates, hooks and rendered changes for APIs supplied by
bootstrap [CRDs](bootstrap/helmfile/crds.yaml) or [core charts](bootstrap/helmfile/apps.yaml).
This coverage is maintained by hand; release notes alone are insufficient.
The [parent patch](kubernetes/flux/cluster/ks.yaml) sets CRD
`CreateReplace`; leaf files and Helm defaults do not establish effective policy.
For human-controlled merges, read the Renovate review first; a
missing/malformed/unavailable review requires manual inspection or a rerun.
Act on blockers and correct recurring prompt mismatches with intentional
repository policy. Preserve PR automerge's [source
configuration](.renovaterc.json5) and the human-companion-commit protection
in AGENTS.

### Tooling

CI scripts use bash, `set -euo pipefail`, a wrapper for external tools,
warning-level ShellCheck and offline branch fixtures. Run the chart fixtures
when changing those scripts or messages; after labelling a pull request
`verify/declared`, push a fresh commit, because old-job reruns keep their
original labels. Operator workflows stay in `just`; mise owns
tools/environment. Keep tool pins and lock coherent, and credentials and
workstation preferences out of mise configuration. A hook declaration is not
evidence it ran.

## Write for the record

Write architecture and procedures for a competent operator new to this
repository; agent-only instructions need direct, unambiguous rules.

### Ownership

[Standing decisions](docs/policy/decisions.md) hold decisions and brief
reasons; approved PRs carry change rationale. No new numbered ADRs.
[AGENTS](AGENTS.md) owns change control, and [docs/README](docs/README.md)
retrieves retired history.

Issues hold decisions and tracking. Check for an existing tracker; a small
issue needs a paragraph and closing condition. Use `.github/ISSUE_TEMPLATE/`
for larger work, removing unused sections. Settle owner decisions before
drafting. Include a rollout runbook when reconciliation alone cannot deliver
the change; maintenance approval follows its
[skill](.agents/skills/maintenance-window/SKILL.md).

### Evidence and review

Lead with the trigger, change, reasons, checks, results and limits. Name actors,
define terms and keep names consistent. Verify numbers and cited sources this
session; label unchecked outcomes and narrow weak claims to evidence. Explain
peer reasoning locally, name post-merge checks and state remaining limits.

Separate editorial review is warranted when a false claim would be costly
(irreversible work, credentials, auth, storage or pre-merge uncertainty).
Supply changed files and diff; record findings, time and tokens, distinguishing
preferences. Requested technical reviews still follow their own scope.
Renovate's bot is the default review on the version bump's own PR.

### Publication and maintenance

Post only when authorised. Settle the branch name first; order dependent
artifacts so links resolve. Link umbrella children as native sub-issues.
Keep the PR body current as scope/evidence changes and before merge; it owns
the rationale under the title-only squash convention. Comments carry substantive
evidence, at most one per milestone; correct errors in place. Create durable
follow-up issues or umbrella rows before closing their source issue.

Follow [public-safety rules](AGENTS.md#treat-this-repository-as-public).
Use categories, not sensitive values; a published leak needs deletion and
reposting. Keep audit topology private and findings where the driving issue
requires. No ceremonial headings, emoji, AI attribution or celebratory endings.
Wrap repository prose at 80 columns; public discussion uses one line per
paragraph. Link other repositories through `https://redirect.github.com/...`
to avoid upstream cross-reference events.

## Keep documents true

A leaf does one job in about 800 words or fewer and opens with a line saying
when it was last verified and against what. ARCHITECTURE.md and
policy/decisions.md are exempt from the leaf budget; the former is the one
mandatory read, the latter a register whose entries are the unit, each under
about 300 words. Each week an agent re-verifies one document against the
cluster, then updates that line or corrects the document. Instructions and
operating limits belong in documents; lessons and incident narrative do not.

A register a command can regenerate is that command plus a link, never a
maintained table. A register that records decisions is maintained by hand
under `docs/policy/`, each entry dated and linked by its anchor.
