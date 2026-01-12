#!/usr/bin/env bash
set -euo pipefail

NS="${COSTANZA_NS:-default}"
SVC="${COSTANZA_SVC:-costanza}"

kubectl -n "$NS" run -it --rm curl \
  --image=curlimages/curl:8.5.0 --restart=Never -- \
  curl -sS "http://${SVC}.${NS}.svc.cluster.local/healthz"
echo
