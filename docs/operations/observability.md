# Observability

Where to look when investigating cluster behaviour, and how to query each
store from a terminal: logs in VictoriaLogs, metrics in Prometheus,
dashboards in Grafana. Alert-interpretation caveats are in
[`../guides/validation.md`](../guides/validation.md).

## Logs: VictoriaLogs

Every pod's stdout and stderr is shipped to VictoriaLogs (service
`victoria-logs` in `observability`, HTTP port 9428), so pod log rotation and
pod replacement do not lose history — a controller's behaviour from weeks
ago is still queryable long after `kubectl logs` has nothing. Collection
began 2026-08-07; nothing earlier exists, and the live window should be
checked before assuming old events are still held.

Query with LogsQL over the HTTP API through a short-lived port-forward:

```sh
kubectl -n observability port-forward svc/victoria-logs 9428:9428 &
curl -s http://localhost:9428/select/logsql/query \
  --data-urlencode 'query=kubernetes.pod_name:~"descheduler" AND "Evicted"' \
  --data-urlencode 'start=2026-08-27T00:00:00Z' \
  --data-urlencode 'end=2026-08-28T00:00:00Z' \
  --data-urlencode 'limit=10'
```

Useful structured fields: `kubernetes.pod_namespace`, `kubernetes.pod_name`,
`kubernetes.container_name`, `kubernetes.pod_node_name`; the message is
`_msg` and the timestamp `_time`. Aggregate with stats pipes — for example
`| stats by (_time:1d) count() n` for a per-day histogram, or
`| stats min(_time) first, max(_time) last, count() n` to bound when
something started and stopped. Tuppr's per-node upgrade jobs ship here too,
including the installer completion and sd-boot probe lines that
[`node-upgrades.md`](node-upgrades.md) relies on.

## Metrics: Prometheus

Upstream Prometheus via kube-prometheus-stack (service
`kube-prometheus-stack-prometheus` in `observability`, port 9090), with a
14-day retention window — request audits and sizing questions reaching
further back need another source. Alertmanager is
`kube-prometheus-stack-alertmanager` on port 9093.

## Dashboards: Grafana

Grafana is operator-managed (`grafana-service`, port 3000); dashboards are
declared in `kubernetes/apps/observability/grafana/dashboards/`.
`home-ops-cockpit` is the operational overview. Known caveat: its
failed-jobs panel counts pod-level retries, so a burst there is not by
itself a backup failure — judge backup health by Kopiur Snapshot phases
([`node-upgrades.md`](node-upgrades.md)).

## Triage order

The cockpit dashboard for the shape of the problem; firing alerts next,
read against validation.md's caveats; then VictoriaLogs for the implicated
pods' history; `kubectl describe` and events for current object state.
