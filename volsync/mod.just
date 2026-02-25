set positional-arguments := true
set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

volsync_dir := justfile_dir() + '/volsync'

[private]
default:
    just -l volsync

[doc('List snapshots (and corresponding previous offset integers) in the restic repo for an app')]
list-previous ns app:
    kubectl -n "{{ ns }}" get secret "{{ app }}-volsync-secret" \
        -o go-template='{{ "{{" }}range $k,$v := .data{{ "}}" }}'\
        '{{ "{{" }}printf "export %s=%s\n" $k ($v|base64decode){{ "}}" }}{{ "{{" }}end{{ "}}" }}' \
        | bash -euo pipefail -c 'source /dev/stdin && restic snapshots --json' \
        | jq -r '[.. | objects | select(has("id") and has("time")) | {id: (.short_id // .id[0:8]), time: (.time | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601 | strflocaltime("%Y-%m-%d %H:%M:%S")), host: (.hostname // ""), tags: ((.tags // []) | join(",")), paths: ((.paths // []) | join(",")), bytes: (.summary.total_bytes_processed // 0)}] | unique_by(.id) | sort_by(.time) | reverse | to_entries[] | [(.key | tostring), .value.id, .value.time, .value.host, .value.tags, .value.paths, (.value.bytes | tostring)] | @tsv' \
        | awk -F $'\t' 'function humansize(n, mib, gib, tib){mib=1024*1024; gib=mib*1024; tib=gib*1024; if(n>=tib)return sprintf("%.3f TiB",n/tib); if(n>=gib)return sprintf("%.3f GiB",n/gib); if(n>=mib)return sprintf("%.3f MiB",n/mib); if(n>=1024)return sprintf("%.3f KiB",n/1024); return sprintf("%d B",n)} BEGIN{printf "%-4s  %-8s  %-19s  %-10s  %-10s  %-5s  %s\n","Prev","ID","Time","Host","Tags","Paths","Size"; print "--------------------------------------------------------------------------------"} {printf "%-4s  %-8s  %-19s  %-10s  %-10s  %-5s  %s\n",$1,$2,$3,$4,$5,$6,humansize($7+0)} END{print "--------------------------------------------------------------------------------"}'

[doc('Restore an app from a snapshot based on previous offset integer (0=latest)')]
restore ns app previous:
    just volsync restore-run "{{ ns }}" "{{ app }}" "{{ previous }}"

[doc('Resume VolSync')]
resume:
    just kube volsync resume

[doc('Snapshot an app')]
snapshot ns app:
    just kube snapshot-app "{{ ns }}" "{{ app }}"

[doc('Suspend VolSync')]
suspend:
    just kube volsync suspend

[doc('Unlock a restic source repo for an app using a Job')]
unlock-local ns app:
    APP="{{ app }}" NS="{{ ns }}" just template "{{ volsync_dir }}/unlock.yaml.j2" \
        | kubectl apply --server-side -f -
    until kubectl -n "{{ ns }}" get job/volsync-unlock-{{ app }} &>/dev/null; do sleep 5; done
    kubectl -n "{{ ns }}" wait job/volsync-unlock-{{ app }} --for=condition=complete --timeout=5m
    stern -n "{{ ns }}" job/volsync-unlock-{{ app }} --no-follow
    kubectl -n "{{ ns }}" delete job volsync-unlock-{{ app }}

[doc('Unlock all restic source repos')]
unlock:
    kubectl get replicationsources --all-namespaces \
        -o jsonpath='{range .items[*]}{.metadata.namespace},{.metadata.name}{"\n"}{end}' | \
        while IFS=, read -r ns app; do \
            [ -n "$$ns" ] && [ -n "$$app" ] || continue; \
            kubectl -n "$$ns" patch replicationsources "$$app" \
                --type merge --ignore-not-found=true \
                --patch "{\"spec\":{\"restic\":{\"unlock\":\"$(date +%s)\"}}}"; \
    done

[private]
restore-run ns app previous:
    [[ "{{ previous }}" =~ ^[0-9]+$ ]] || { \
        echo "previous must be an integer offset (0=latest, 1=one snapshot back)" >&2; \
        exit 1; \
    }
    flux -n "{{ ns }}" suspend kustomization "{{ app }}"
    flux -n "{{ ns }}" suspend helmrelease "{{ app }}"
    just volsync keda-pause "{{ ns }}" "{{ app }}" || true
    kubectl -n "{{ ns }}" scale \
        "$(just volsync detect-controller "{{ ns }}" "{{ app }}")/{{ app }}" \
        --replicas=0
    kubectl -n "{{ ns }}" wait pod --for=delete \
        --selector="app.kubernetes.io/name={{ app }}" --timeout=5m || true
    rs="replicationsources/{{ app }}"
    claim="$(kubectl -n "{{ ns }}" get "$rs" -o jsonpath='{.spec.sourcePVC}')"; \
    access_modes="$(kubectl -n "{{ ns }}" get "$rs" -o jsonpath='{.spec.restic.accessModes}')"; \
    storage_class_name="$(kubectl -n "{{ ns }}" get "$rs" \
        -o jsonpath='{.spec.restic.storageClassName}')"; \
    puid="$(kubectl -n "{{ ns }}" get "$rs" \
        -o jsonpath='{.spec.restic.moverSecurityContext.runAsUser}')"; \
    pgid="$(kubectl -n "{{ ns }}" get "$rs" \
        -o jsonpath='{.spec.restic.moverSecurityContext.runAsGroup}')"
    APP="{{ app }}" \
        NS="{{ ns }}" \
        PREVIOUS="{{ previous }}" \
        CLAIM="$claim" \
        ACCESS_MODES="$access_modes" \
        STORAGE_CLASS_NAME="$storage_class_name" \
        PUID="$puid" \
        PGID="$pgid" \
            just template "{{ volsync_dir }}/replicationdestination.yaml.j2" \
            | kubectl apply --server-side -f -
    until kubectl -n "{{ ns }}" get job/volsync-dst-{{ app }}-manual &>/dev/null; do sleep 5; done
    kubectl -n "{{ ns }}" wait job/volsync-dst-{{ app }}-manual \
        --for=condition=complete --timeout=120m
    kubectl -n "{{ ns }}" delete replicationdestination "{{ app }}-manual" --ignore-not-found
    flux -n "{{ ns }}" resume kustomization "{{ app }}"
    flux -n "{{ ns }}" resume helmrelease "{{ app }}"
    flux -n "{{ ns }}" reconcile helmrelease "{{ app }}" --force
    just volsync keda-unpause "{{ ns }}" "{{ app }}" || true
    kubectl -n "{{ ns }}" wait pod --for=condition=ready \
        --selector="app.kubernetes.io/name={{ app }}" --timeout=5m || true

[private]
detect-controller ns app:
    if kubectl -n "{{ ns }}" get deployment "{{ app }}" >/dev/null 2>&1; then echo deployment; \
    elif kubectl -n "{{ ns }}" get statefulset "{{ app }}" >/dev/null 2>&1; then echo statefulset; \
    else echo "No deployment/statefulset found for {{ ns }}/{{ app }}" >&2; exit 1; fi

[private]
keda-pause ns app:
    if kubectl -n "{{ ns }}" get scaledobject "{{ app }}" >/dev/null 2>&1; then \
        kubectl -n "{{ ns }}" annotate scaledobject/{{ app }} \
            kustomize.toolkit.fluxcd.io/reconcile=disabled --overwrite; \
        kubectl -n "{{ ns }}" annotate scaledobject/{{ app }} \
            autoscaling.keda.sh/paused="true" autoscaling.keda.sh/paused-replicas="0" --overwrite; \
    fi

[private]
keda-unpause ns app:
    if kubectl -n "{{ ns }}" get scaledobject "{{ app }}" >/dev/null 2>&1; then \
        kubectl -n "{{ ns }}" annotate scaledobject/{{ app }} \
            autoscaling.keda.sh/paused- autoscaling.keda.sh/paused-replicas-; \
        kubectl -n "{{ ns }}" annotate scaledobject/{{ app }} \
            kustomize.toolkit.fluxcd.io/reconcile=enabled --overwrite; \
    fi
