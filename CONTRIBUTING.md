# Contributing

Verified 2026-10-05 against the repository at `main`.

Read [ARCHITECTURE.md](ARCHITECTURE.md) first; it also says what CI proves.
Agents follow [AGENTS.md](AGENTS.md) for boundaries and routing. Compare with
other clusters through the [peers catalogue](docs/peers.md).

## Validate locally

Verified 2026-10-05 against the repository at `main` with Flate 0.6.5; not
against the live cluster.

Run the smallest set of checks that matches the change, read what they print,
and report what they did not prove. Use the pinned tools through `mise exec`.

| Change                         | Run                                                                                               | Proves                                                                 | Does not prove                                                |
| ------------------------------ | ------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- | ------------------------------------------------------------- |
| App manifests                  | Kustomize build and Flate test; image comparison when images may change                           | The app builds, the tree renders, and which images are new             | See [what a local render proves](#what-a-local-render-proves) |
| Chart or operator upgrades     | As for app manifests, plus the [CRD upgrade checks](docs/policy/decisions.md#crd-upgrades)        | The rendered change, including hooks and templates you inspected       | That APIs supplied by bootstrap match the new chart           |
| Workflows, CI scripts, tooling | Formatting, actionlint, zizmor, ShellCheck and the chart fixtures; read the changed Actions logic | Syntax, known workflow risks and script behaviour on the offline cases | Behaviour on GitHub's runners, with real tokens and events    |
| Storage                        | The [restore evidence](.agents/skills/restore-data/SKILL.md) relevant to the risk                 | What that evidence exercised                                           | Anything it did not exercise                                  |
| Docs                           | Formatting; run every changed command or procedure                                                | Format, and the commands you ran                                       | Links and prose: Lint checks neither                          |

The first four commands are the ones Lint runs, and the fifth is Chart
Verify's Fixtures job:

```bash
# Formatting of JSON, TOML, YAML and Markdown; SOPS files are never reformatted
mise exec --no-deps -- oxfmt --check . '!**/*.sops.yaml' '!**/*.sops.yml'
# Workflow syntax and expressions
mise exec --no-deps -- actionlint
# Workflow security audits that need no network
mise exec --no-deps -- zizmor --offline .github/workflows
# Shell scripts and the fixture stand-in, at warning level
mise exec --no-deps -- shellcheck -S warning $(git ls-files '*.sh' '.github/tests/chart-signing/bin/_fake')
# Chart Verify's scripts against their offline cases
.github/tests/chart-signing/run.sh
# One app's own resources; its components and parent patches are not applied
mise exec -- kubectl kustomize kubernetes/apps/<namespace>/<app>/app
# Every Kustomization, HelmRelease and Flux source renders
mise exec -- flate test all -p ./kubernetes/flux/cluster --allow-missing-secrets
```

Keep `test all` full-tree: adding `--base` switches it to changed-only mode.

Image comparison needs a base revision. Run Flate base comparisons from a plain
clone of the committed candidate, made with `git clone --no-local`, and replace
`origin/main` with the reviewed base:

```bash
# Images the candidate adds relative to the base; [] means none
mise exec -- flate diff images -p ./kubernetes/flux/cluster --base origin/main -o json
```

### What a local render proves

Flate renders the working tree without a cluster
([behaviour and limits](https://redirect.github.com/home-operations/flate/blob/631b76b69c4e58c6f4d1cb01e23616fa61aebafa/README.md#behaviors)).
Read the rendered objects, the base and the warnings, not only the pass count.
A clean run does not cover:

- substitution values held only in the live cluster, which render empty and
  appear as warnings;
- SOPS values, which render as placeholders;
- sources and consumers that `--allow-missing-secrets` skipped;
- Secrets and CRDs, which are left out of the output by default;
- chart signatures, decryption, admission or runtime health.

Server dry-run tests admission, not runtime success. Follow
[access](docs/operations/access.md) to choose the identity, and confirm the
tunnel and the response succeeded before trusting the result.

### Changing CI scripts and tooling

CI scripts are bash with `set -euo pipefail`. Call external tools through the
script's `tool` wrapper, so the fixtures can substitute stand-ins, and keep the
scripts clean under ShellCheck at warning level. Run the chart fixtures when
changing those scripts or their messages. After labelling a pull request
`verify/declared`, push a fresh commit, because a rerun of an old job keeps its
original labels.

Operator workflows stay in `just`; mise owns tools and environment. Keep tool
pins and the lock file coherent, and keep credentials and workstation
preferences out of mise configuration.

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

Before a human-controlled merge, read that review; if it is missing, malformed
or unavailable, inspect the change by hand or rerun the review. Act on its
blockers, and correct a recurring mismatch with the prompt through deliberate
repository policy. Preserve PR automerge's
[source configuration](.renovaterc.json5) and the
[companion-commit protection](AGENTS.md#working-here).

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
