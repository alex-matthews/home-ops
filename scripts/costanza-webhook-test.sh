#!/usr/bin/env bash
set -euo pipefail

command -v kubectl >/dev/null 2>&1 || { echo "Missing kubectl" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "Missing curl" >&2; exit 1; }

NS="${COSTANZA_NS:-default}"
SVC="${COSTANZA_SVC:-costanza}"
LOCAL_PORT="${COSTANZA_LOCAL_PORT:-8001}"
TARGET_PORT="${COSTANZA_TARGET_PORT:-80}"

SECRET="${COSTANZA_SECRET:-costanza-secret}"
TOKEN="$(kubectl -n "$NS" get secret "$SECRET" -o jsonpath='{.data.JELLYSEERR_WEBHOOK_TOKEN}' | base64 -d)"

PF_LOG="$(mktemp -t costanza-portforward.XXXXXX.log)"

kubectl -n "$NS" port-forward "svc/${SVC}" "${LOCAL_PORT}:${TARGET_PORT}" >"$PF_LOG" 2>&1 &
PF_PID=$!
trap 'kill "$PF_PID" >/dev/null 2>&1 || true; rm -f "$PF_LOG" >/dev/null 2>&1 || true' EXIT

# Wait for port-forward to start accepting connections
for _ in $(seq 1 50); do
  # If port-forward died, fail early and show logs
  if ! kill -0 "$PF_PID" >/dev/null 2>&1; then
    echo "port-forward exited early; log follows:" >&2
    sed -n '1,200p' "$PF_LOG" >&2 || true
    exit 1
  fi

  # Health probe (quiet). If it works, we're ready.
  if curl -fsS "http://localhost:${LOCAL_PORT}/healthz" >/dev/null 2>&1; then
    break
  fi

  sleep 0.2
done

curl -fsS "http://localhost:${LOCAL_PORT}/healthz" >/dev/null 2>&1 || {
  echo "port-forward never became ready; log follows:" >&2
  sed -n '1,200p' "$PF_LOG" >&2 || true
  exit 1
}

curl -sS -X POST "http://localhost:${LOCAL_PORT}/webhooks/jellyseerr" \
  -H "Content-Type: application/json" \
  -H "X-Webhook-Token: ${TOKEN}" \
  -d '{"notification_type":"TEST_NOTIFICATION","subject":"K8s test","message":"hello from port-forward"}'
echo
