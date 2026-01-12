set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

kubernetes_dir := justfile_dir() + '/scripts'

[private]
default:
    just -l scripts

# ---- Costanza scripts (including webhook test) ----

COSTANZA_NS := "default"
COSTANZA_SVC := "costanza"
COSTANZA_LOCAL_PORT := "8001"
COSTANZA_TARGET_PORT := "80"

costanza-health:
    kubectl -n {{ COSTANZA_NS }} run -it --rm curl \
      --image=curlimages/curl:8.5.0 --restart=Never -- \
      curl -sS http://{{ COSTANZA_SVC }}.{{ COSTANZA_NS }}.svc.cluster.local/healthz ; \
    echo

costanza-port-forward:
    kubectl -n {{ COSTANZA_NS }} port-forward svc/{{ COSTANZA_SVC }} {{ COSTANZA_LOCAL_PORT }}:{{ COSTANZA_TARGET_PORT }}

costanza-webhook-test:
    TOKEN="$$(kubectl -n {{ COSTANZA_NS }} get secret costanza-secret -o jsonpath='{.data.JELLYSEERR_WEBHOOK_TOKEN}' | base64 -d | tr -d '\n')" ; \
    kubectl -n {{ COSTANZA_NS }} port-forward svc/{{ COSTANZA_SVC }} {{ COSTANZA_LOCAL_PORT }}:{{ COSTANZA_TARGET_PORT }} >/tmp/costanza-pf.log 2>&1 & \
    PF_PID=$$! ; \
    trap 'kill $$PF_PID >/dev/null 2>&1 || true' EXIT ; \
    for i in {1..25}; do \
      curl -fsS "http://localhost:{{ COSTANZA_LOCAL_PORT }}/healthz" >/dev/null 2>&1 && break; \
      sleep 0.2; \
    done ; \
    curl -sS -X POST "http://localhost:{{ COSTANZA_LOCAL_PORT }}/webhooks/jellyseerr" \
      -H 'Content-Type: application/json' \
      -H "X-Webhook-Token: $${TOKEN}" \
      -d '{"notification_type":"TEST_NOTIFICATION","subject":"K8s test","message":"hello from port-forward"}' ; \
    echo
