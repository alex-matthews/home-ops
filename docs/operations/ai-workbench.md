# AI Workbench Prompts

This page collects starter prompts for interactive use with Hermes and the
ToolHive MCP workbench. Some prompts have been exercised, but the collection is
not a reliability guarantee. The architecture and rollout rationale live in
[`../adr/0001-ai-home-ops-workbench.md`](../adr/0001-ai-home-ops-workbench.md).

Use these prompts as starting points, not as durable decisions. Write durable
tasks, findings, and decisions back to GitHub issues, pull requests, ADRs, or
repository docs.

## Operating Rules

- The current ToolHive workbench surface is read-only by default and is intended
  for Context7, GitHub, Konflate, Flux, and Grafana evidence.
- The internal ToolHive route is for trusted LAN or WireGuard clients such as
  Hermes and Codex. Do not expose it through `envoy-external` without a separate
  authentication decision.
- Prefer summary tools first. Drill into broad resource lists only after the
  summary shows a problem.
- Ask for evidence from the named MCP surface rather than accepting a generic
  model answer.
- Keep the model from delegating when the task needs a bounded, auditable tool
  path.
- Keep write actions out of workbench prompts unless a separate approval
  boundary exists.
- Do not paste secrets. Refer to configured GitHub secrets, repository vars, or
  manifest substitutions by name.

If Hermes lists MCP tools but calls fail with `MCP event loop is not running`,
restart the Hermes gateway from the UI, then run:

```text
/reload-mcp now
```

## Codex MCP Access

Codex can consume the same ToolHive vMCP surface through the internal route:

```sh
codex mcp add toolhive --url "https://toolhive.${SECRET_DOMAIN}/mcp"
```

Keep local Codex MCP configuration, OAuth state, and bearer tokens out of this
repository. If Codex is not on the trusted internal network, use a temporary
`kubectl port-forward` instead of adding a public route.

The current route is an internal-only bridge for stress-testing the workbench
surface. Before exposing ToolHive more broadly, switch the vMCP to ToolHive
native OIDC or an equivalent explicit auth boundary.

## Flux Health

Use this for a quick GitOps health check.

```text
Using Flux MCP, inspect GitOps health.

Call flux_get_flux_instance only.

From the FluxReport, report aggregate running/failing/suspended counts for:
- Kustomization
- HelmRelease

If failing is 0 for both, stop and say there are no reported non-ready
Kustomizations or HelmReleases.

If failing is greater than 0 for either kind, do not dump broad resources. Ask
me which namespace to inspect next.

Also include FluxInstance Ready status, reason, lastTransitionTime, and the
GitRepository revision if present.

Do not delegate.
Do not call flux_get_kubernetes_resources unless I explicitly ask for a
namespace follow-up.
Do not suggest kubectl or flux write actions.
```

Follow-up for one namespace only:

```text
Using Flux MCP, inspect Flux resources in namespace <NAMESPACE> only.

Call flux_get_kubernetes_resources for:
- Kustomization using kustomize.toolkit.fluxcd.io/v1
- HelmRelease using helm.toolkit.fluxcd.io/v2

Return only resources whose Ready condition is missing or whose Ready.status is
not "True".

For each resource include namespace, kind, name, Ready status, reason, message,
and lastTransitionTime.

Do not delegate.
Do not query other namespaces.
Do not suggest kubectl or flux write actions.
```

## Konflate Pull Request Review

Use this before reviewing a Kubernetes, Helm, Flux, or container-image pull
request.

```text
Using Konflate MCP, review PR #<PR_NUMBER>.

Call konflate_get_pr_summary for this exact pull request number first.

Report:
- total resources added, changed, and removed
- apps or namespaces touched, if the summary includes them
- cautions separately from ordinary changes
- whether Konflate reports no rendered changes

If the summary includes cautions, removed resources, CRDs, RBAC, storage,
ingress, route, backup, or secret changes, call konflate_get_pr_diff for the
same pull request number and cite the rendered resources behind those findings.

Do not use any other pull request number.
Do not treat Konflate as a merge gate. State that it is advisory evidence.
Do not print MCP endpoint URLs.
```

## GitHub Pull Request Context

Use this to understand a pull request before touching files.

```text
Using GitHub MCP, summarize PR #<PR_NUMBER> in alex-matthews/home-ops.

Call github_pull_request_read for the pull request.
Call github_actions_list for the pull request branch or head SHA if available.

Return:
- title, author, branch, mergeability if available, and current review state
- changed files grouped by area
- required or relevant check status
- linked issues mentioned in the body
- whether the PR looks like Renovate, Codex, or human-authored work

Do not make recommendations unless the evidence supports them.
Do not suggest write actions.
```

Use this for recent repository context:

```text
Using GitHub MCP, summarize the latest 5 commits on alex-matthews/home-ops main.

For each commit include:
- short SHA
- title
- author
- whether it touched kubernetes/apps/ai

If the file list is unavailable from the list call, fetch each commit by SHA
with github_get_commit.
```

## Grafana Observability

Use this for read-only observability checks.

```text
Using Grafana MCP, investigate <APP_OR_COMPONENT>.

Search dashboards first with grafana_search_dashboards. If a likely dashboard is
found, summarize it with grafana_get_dashboard_summary.

Then query recent Loki logs with grafana_query_loki_logs using narrow labels for
namespace and app when possible.

Return:
- dashboards checked
- error or warning log patterns from the last <TIME_WINDOW>
- any obvious rollout or crash loop signal
- links generated by grafana_generate_deeplink when useful

Do not use generic Grafana API request tools.
Do not modify dashboards, alerts, routing, or datasources.
Do not broaden the log query without asking first.
```

## Context7 Documentation Lookup

Use this when checking current upstream docs for a library, chart, or tool.

```text
Using Context7 MCP, look up current documentation for <PROJECT_OR_LIBRARY>.

First call context7_resolve-library-id. Then call context7_query-docs for the
resolved library.

Answer with:
- the relevant current behavior
- the exact option, field, or command name when applicable
- a short note if the docs do not cover the question

Do not answer from memory if Context7 has relevant documentation.
```

## Cross-Tool PR Evidence

Use this when asking the workbench for an advisory PR review. It should produce
evidence, not a substitute for human review.

```text
Review PR #<PR_NUMBER> in alex-matthews/home-ops using the available MCP tools.

Use GitHub MCP to read the pull request, changed files, latest commit, and check
status.

If the PR touches Kubernetes, Helm, Flux, routes, storage, secrets, RBAC,
container images, or GitHub Actions, use Konflate MCP for rendered-diff evidence.
Call konflate_get_pr_summary first. Call konflate_get_pr_diff only when the
summary or changed files show material cluster impact.

If the PR touches an app that is already deployed, use Flux MCP only for summary
health context. Call flux_get_flux_instance only unless I ask for a namespace
follow-up.

If runtime evidence is needed, use Grafana MCP with narrow dashboard or Loki
queries.

Return:
- recommendation: approve, comment, or request changes
- highest-risk findings first, with file/resource references
- evidence used from GitHub, Konflate, Flux, and Grafana
- unknowns that could not be verified

Keep the report concise.
Do not delegate.
Do not use broad cluster inventory calls.
Do not suggest write actions.
Do not print endpoint URLs or secrets.
```
