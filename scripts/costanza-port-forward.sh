#!/usr/bin/env bash
set -euo pipefail

NS="${COSTANZA_NS:-default}"
SVC="${COSTANZA_SVC:-costanza}"
LOCAL_PORT="${COSTANZA_LOCAL_PORT:-8001}"
TARGET_PORT="${COSTANZA_TARGET_PORT:-80}"

kubectl -n "$NS" port-forward "svc/${SVC}" "${LOCAL_PORT}:${TARGET_PORT}"
