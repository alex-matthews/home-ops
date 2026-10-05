# Observability

Verified 2026-10-05 against the repository at `main`; not against the live
cluster.

Start with the home-ops cockpit dashboard in Grafana at
`grafana.${SECRET_DOMAIN}`, then alerts, affected workloads' logs and current
object descriptions/events.
[Architecture](../../ARCHITECTURE.md#seeing-failures) explains why observation
can fail with the cluster.

Place a failure in one of three kinds before diagnosing it:

- **A revision not applied.** A Flux Kustomization or HelmRelease is not
  Ready at the expected revision, and Flux's alerts report it. Read its
  conditions and events.
- **An unhealthy workload.** The objects applied, but pods crash, stay
  pending or fail probes. Read pod status, events and the firing alerts.
- **A running app behaving wrongly.** Objects and pods are healthy. Use the
  app's logs and metrics.

The cockpit queries Prometheus firing rules without Alertmanager suppression.
Check Alertmanager's alert status and the [declared
silences](../../kubernetes/apps/observability/silence-operator/silences)
before reporting a condition as new; a new silence is a `Silence` added there
by pull request. Suppression is context with an expiry, not proof of health.
Inspect rule evaluation errors before interpreting garbled annotations. The
[failed-jobs
panel](../../kubernetes/apps/observability/grafana/dashboards/home-ops/cockpit/prometheusrule.yaml)
counts Jobs with recent failures, not failed backups; inspect the owning
Snapshot/Restore using [backups](backups.md#maintenance-and-health).

Prometheus and VictoriaLogs have bounded retention; Prometheus also has a
size limit. Check collection and the available window before concluding an
old event is absent. VictoriaLogs can retain Job logs after their pods are
gone. Use namespace/pod/container selectors, a time range and a result limit
in [LogsQL](https://docs.victoriametrics.com/victorialogs/querying/).
[Datasource declarations](../../kubernetes/apps/observability/grafana/instance/grafanadatasource.yaml)
identify the services. For API queries through a short-lived port-forward,
select the [authorised identity](access.md), confirm the tunnel and response
succeeded, and close it afterwards. Failed access is not an empty data set.
