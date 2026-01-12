set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

kubernetes_dir := justfile_dir() + '/scripts'

[private]
default:
    just -l scripts

COSTANZA_NS := "default"
COSTANZA_SVC := "costanza"
COSTANZA_LOCAL_PORT := "8001"
COSTANZA_TARGET_PORT := "80"

costanza-health:
    {{ kubernetes_dir }}/costanza-health.sh

costanza-port-forward:
    {{ kubernetes_dir }}/costanza-port-forward.sh

costanza-webhook-test:
    {{ kubernetes_dir }}/costanza-webhook-test.sh
