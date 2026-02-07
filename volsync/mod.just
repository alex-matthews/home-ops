set positional-arguments := true
set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

volsync_dir := justfile_dir() + '/volsync'

[private]
default:
    just -l volsync

[doc('Snapshot an app')]
snapshot ns app:
    kubectl -n {{ ns }} patch replicationsources/{{ app }} --type merge \
        --patch "{\"spec\":{\"trigger\":{\"manual\":\"$(date +%s)\"}}}"
    until kubectl -n {{ ns }} get job/volsync-src-{{ app }} &>/dev/null; do sleep 5; done
    kubectl -n {{ ns }} wait job/volsync-src-{{ app }} --for=condition=complete --timeout=120m

[doc('List snapshots in the restic repo for an app')]
list-snapshots ns app:
    kubectl -n {{ ns }} get secret {{ app }}-volsync-secret \
      -o go-template='{{ "{{" }}range $k,$v := .data{{ "}}" }}{{ "{{" }}printf "export %s=%s\n" $k ($v|base64decode){{ "}}" }}{{ "{{" }}end{{ "}}" }}' \
      | bash -c 'source /dev/stdin && restic snapshots'

[doc('Restore an app based on a previous snapshot')]
restore ns app previous:
    CONTROLLER=$(just volsync detect-controller-type {{ ns }} {{ app }})

    # Suspend Flux reconciliation
    flux -n {{ ns }} suspend kustomization {{ app }}
    flux -n {{ ns }} suspend helmrelease {{ app }}

    # Pause KEDA scaling (no-op if ScaledObject doesn't exist)
    just volsync keda-pause {{ ns }} {{ app }} || true

    # Scale down workload and wait for pods to terminate
    kubectl -n {{ ns }} scale $CONTROLLER/{{ app }} --replicas=0
    kubectl -n {{ ns }} wait pod --for=delete \
        --selector="app.kubernetes.io/name={{ app }}" --timeout=5m || true

    # Template out ReplicationDestination (apply triggers restore)
    APP={{ app }} \
    NS={{ ns }} \
    PREVIOUS={{ previous }} \
    CLAIM="$(kubectl -n {{ ns }} get replicationsources/{{ app }} -o jsonpath='{.spec.sourcePVC}')" \
    ACCESS_MODES="$(kubectl -n {{ ns }} get replicationsources/{{ app }} -o jsonpath='{.spec.restic.accessModes[0]}')" \
    STORAGE_CLASS_NAME="$(kubectl -n {{ ns }} get replicationsources/{{ app }} -o jsonpath='{.spec.restic.storageClassName}')" \
    PUID="$(kubectl -n {{ ns }} get replicationsources/{{ app }} -o jsonpath='{.spec.restic.moverSecurityContext.runAsUser}')" \
    PGID="$(kubectl -n {{ ns }} get replicationsources/{{ app }} -o jsonpath='{.spec.restic.moverSecurityContext.runAsGroup}')" \
    bash -c '\
    for var in APP NS PREVIOUS CLAIM ACCESS_MODES STORAGE_CLASS_NAME PUID PGID; do
    eval val=\$$var
    [ -n "$val" ] || { echo "ERROR: $var is empty - aborting restore" >&2; exit 1; }
    done
    just template {{ volsync_dir }}/replicationdestination.yaml.j2 \
    | kubectl apply --server-side -f -'

    # Wait for restore job
    until kubectl -n {{ ns }} get job/volsync-dst-{{ app }}-manual &>/dev/null; do sleep 5; done
    kubectl -n {{ ns }} wait job/volsync-dst-{{ app }}-manual --for=condition=complete --timeout=120m

    # Clean up ReplicationDestination
    kubectl -n {{ ns }} delete replicationdestination {{ app }}-manual || true

    # Resume Flux reconciliation
    flux -n {{ ns }} resume kustomization {{ app }}
    flux -n {{ ns }} resume helmrelease {{ app }}
    flux -n {{ ns }} reconcile helmrelease {{ app }} --force

    # Wait for pods to be ready again
    kubectl -n {{ ns }} wait pod --for=condition=ready \
        --selector="app.kubernetes.io/name={{ app }}" --timeout=5m || true

    # Unpause KEDA
    just volsync keda-unpause {{ ns }} {{ app }} || true

[doc('Unlock a restic source repo for an app using a Job')]
unlock-local ns app:
    APP={{ app }} NS={{ ns }} just template {{ volsync_dir }}/unlock.yaml.j2 \
        | kubectl apply --server-side -f -
    until kubectl -n {{ ns }} get job/volsync-unlock-{{ app }} &>/dev/null; do sleep 5; done
    kubectl -n {{ ns }} wait job/volsync-unlock-{{ app }} --for=condition=complete --timeout=5m
    stern -n {{ ns }} job/volsync-unlock-{{ app }} --no-follow
    kubectl -n {{ ns }} delete job volsync-unlock-{{ app }}

[doc('Unlock all restic source repos')]
unlock:
    for ns_app in $(kubectl get replicationsources --all-namespaces \
        -o jsonpath='{range .items[*]}{.metadata.namespace},{.metadata.name}{"\n"}{end}'); do \
        ns=$$(echo $$ns_app | cut -d, -f1); \
        app=$$(echo $$ns_app | cut -d, -f2); \
        kubectl -n $$ns patch replicationsources $$app --type merge --ignore-not-found=true \
            --patch "{\"spec\":{\"restic\":{\"unlock\":\"$(date +%s)\"}}}"; \
    done

[doc('Suspend VolSync')]
state-suspend:
    flux -n volsync-system suspend kustomization volsync
    flux -n volsync-system suspend helmrelease volsync
    kubectl -n volsync-system scale deployment volsync --replicas=0

[doc('Resume VolSync')]
state-resume:
    flux -n volsync-system resume kustomization volsync
    flux -n volsync-system resume helmrelease volsync
    kubectl -n volsync-system scale deployment volsync --replicas=1

[private]
detect-controller-type ns app:
    kubectl -n {{ ns }} get deployment {{ app }} &>/dev/null && \
      echo deployment || echo statefulset

[private]
keda-pause ns app:
    if kubectl -n {{ ns }} get scaledobject {{ app }} >/dev/null 2>&1; then \
        kubectl -n {{ ns }} annotate scaledobject/{{ app }} \
            kustomize.toolkit.fluxcd.io/reconcile=disabled --overwrite; \
        kubectl -n {{ ns }} annotate scaledobject/{{ app }} \
            autoscaling.keda.sh/paused="true" autoscaling.keda.sh/paused-replicas="0" --overwrite; \
    fi

[private]
keda-unpause ns app:
    if kubectl -n {{ ns }} get scaledobject {{ app }} >/dev/null 2>&1; then \
        kubectl -n {{ ns }} annotate scaledobject/{{ app }} \
            autoscaling.keda.sh/paused- autoscaling.keda.sh/paused-replicas-; \
        kubectl -n {{ ns }} annotate scaledobject/{{ app }} \
            kustomize.toolkit.fluxcd.io/reconcile=enabled --overwrite; \
    fi
