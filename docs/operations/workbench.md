# Workbench

Verified 2026-10-05 against the repository at `main`; not against the live
cluster.

Use the workbench for read-only, evidence-led triage.
[Workbench policy](../policy/decisions.md#workbench-and-automation) owns
adoption and promotion gates.

[LiteLLM declarations](../../kubernetes/apps/ai/litellm/app) own the model
list. A model added in the LiteLLM UI lives only in its database; promote one
worth keeping to a `LiteLLMModel` in Git.

Start with Flux health, datasource reachability, alerts and bounded anomaly
metrics. Query logs once a signal identifies a workload. Report what changed,
what appears benign, what deserves attention and what evidence is missing.
Broad log hunting and duplicate PR review are poor starting points because
existing alerts and kritika already cover those paths.

## Checks

Before accepting a gateway, client or Hermes image change, verify:

- Test primary and auxiliary model requests. Hermes declares a streaming
  workaround for auxiliary calls; assess it when changing the gateway or
  adding a client rather than assuming every client needs the same setting.
  kritika reviews on a ChatGPT plan, signed in as its
  [docs](https://redirect.github.com/home-operations/kritika/blob/0.0.56/docs/models.md#chatgpt-plans)
  describe, and falls back to models that LiteLLM serves on Chat
  Completions, with its own virtual key and weekly budget. LiteLLM also
  serves its embeddings.
- For a new Hermes image, check provider resolution, configuration defaults
  and migrations. Update the read-only ConfigMap deliberately in Git; startup
  cannot repair it. Keep migration checks enabled and preserve dashboard
  authentication on non-loopback binds.
- Discover the current MCP catalogue, verify effective read-only permissions
  and run bounded Flux, GitHub and Grafana queries. Confirm VictoriaLogs
  datasource discovery and a narrow log query using the available tools;
  [observability](observability.md) owns signal interpretation. Do not use
  generic Grafana API request tools for routine triage.

After a tool transport failure, allow Hermes's bounded reconnect handling,
verify the catalogue and retry one bounded call. Investigate persistent
failure before an approved reload/restart; distinguish it from a
model-provider failure. Change display settings rather than lowering
reasoning effort to hide visible reasoning.

Hermes runtime state is on a plain claim with no backup: it survives pod
replacement, not a rebuild or a lost claim.

## Login

Subscription login is separate human-established state: Git and database
recovery do not recreate it. Arrange re-authentication before a rebuild.
Missing login can delay startup while `chatgpt` models enter device flow.
A person performs login using the declared [image and workload
identity](../../kubernetes/apps/ai/litellm/app/litellmproxy.yaml) and
[persistent claim](../../kubernetes/apps/ai/litellm/app/pvc.yaml), avoiding
probe-driven restarts and concurrent token writers. The client must be able
to rewrite its login state on refresh. A printed success is insufficient:
LiteLLM 1.103.2 logs a failed save without raising it. Verify persistence
through metadata and subsequent use without displaying credential contents.
Agents do not execute this flow. The last written procedure, a one-off pod
without probes, is in the retired `docs/operations/ai-workbench.md`
([retrieval](../README.md#retired-documents)); check its pins against the
current declarations before using it.
