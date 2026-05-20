set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

[private]
default:
    just -l kube

[doc('Apply local Flux Kustomization')]
apply-ks ns ks:
    just kube render-local-ks "{{ ns }}" "{{ ks }}" | kubectl apply --server-side --force-conflicts --field-manager=kustomize-controller -f -

[doc('Browse a PVC')]
browse-pvc ns claim:
    kubectl browse-pvc -n "{{ ns }}" -i mirror.gcr.io/alpine:latest "{{ claim }}"

[doc('Cleanup ReplicationDestination artifacts')]
[script]
cleanup-rdst ns app:
    if kubectl -n "{{ ns }}" get hr "{{ app }}" >/dev/null 2>&1 \
        || kubectl -n "{{ ns }}" get ks "{{ app }}" >/dev/null 2>&1; then
        echo "Refusing cleanup-rdst: {{ ns }}/{{ app }} still deployed"
        exit 2
    fi
    kubectl -n "{{ ns }}" delete --ignore-not-found replicationdestination.volsync.backube/{{ app }}-dst
    kubectl -n "{{ ns }}" get volumesnapshot.snapshot.storage.k8s.io -o name 2>/dev/null \
        | grep -E "volsync-{{ app }}-dst-dest" \
        | xargs -r kubectl -n "{{ ns }}" delete --ignore-not-found || true
    kubectl -n "{{ ns }}" get \
        replicationdestination.volsync.backube,volumesnapshot.snapshot.storage.k8s.io \
        2>/dev/null \
        | grep -Ei "{{ app }}-dst|volsync-{{ app }}-dst-dest" || true

[doc('Debug a node')]
[script]
debug-node node:
    trap 'kubectl delete pod -n default -l app.kubernetes.io/managed-by=kubectl-debug --field-selector spec.nodeName={{ node }} --ignore-not-found --wait=false' EXIT
    kubectl debug node/{{ node }} -n default -it --image=mirror.gcr.io/alpine:latest --profile=sysadmin

[doc('Delete local Flux Kustomization')]
delete-ks ns ks:
    just kube render-local-ks "{{ ns }}" "{{ ks }}" | kubectl delete -f -

[arg('state', pattern='suspend|resume')]
[doc('Suspend or resume Keda ScaledObjects')]
[script]
keda state:
    kubectl get scaledobjects --no-headers -A | while read -r ns name _; do
        pause='autoscaling.keda.sh/paused{{ if state != "suspend" { "-" } else { "=true" } }}'
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite \
            so "$name" "$pause"
    done

[doc('Prune pods in Failed, Pending, or Succeeded state')]
[script]
prune-pods:
    for phase in Failed Pending Succeeded; do
        kubectl delete pods -A --field-selector status.phase="$phase" --ignore-not-found=true
    done

[doc('Snapshot all VolSync-backed PVCs')]
[script]
snapshot:
    kubectl get replicationsources --no-headers -A | while read -r ns name _; do
        kubectl -n "$ns" patch replicationsources "$name" --type merge \
            --patch "{\"spec\":{\"trigger\":{\"manual\":\"$(date +%s)\"}}}"
    done

[doc('Snapshot VolSync-backed PVC for a specific app')]
[script]
snapshot-app ns app:
    kubectl -n "{{ ns }}" patch replicationsources/{{ app }} --type merge \
        --patch "{\"spec\":{\"trigger\":{\"manual\":\"$(date +%s)\"}}}"
    until kubectl -n "{{ ns }}" get job/volsync-src-{{ app }} &>/dev/null; do sleep 5; done
    kubectl -n "{{ ns }}" wait job/volsync-src-{{ app }} --for=condition=complete --timeout=120m

[arg('resource', pattern='hr|ks|gitrepo|ocirepo|es')]
[doc('Sync a resource')]
[script]
sync resource:
    kubectl get {{ resource }} --no-headers -A | while read -r ns name _; do
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite {{ resource }} "$name" \
            force-sync="$(date +%s)" \
            reconcile.fluxcd.io/requestedAt="$(date +%s)" \
            reconcile.fluxcd.io/forceAt="$(date +%s)"
    done

[doc('Sync ExternalSecrets')]
sync-es:
    just kube sync es

[doc('Sync GitRepositories')]
sync-git:
    just kube sync gitrepo

[doc('Sync HelmReleases')]
sync-hr:
    just kube sync hr

[doc('Sync Kustomizations')]
sync-ks:
    just kube sync ks

[doc('Sync OCIRepositories')]
sync-oci:
    just kube sync ocirepo

[doc('View a Secret')]
view-secret ns secret:
    kubectl view-secret -n "{{ ns }}" "{{ secret }}"

[arg('state', pattern='suspend|resume')]
[doc('Suspend or resume VolSync')]
volsync state:
    flux -n volsync-system {{ state }} kustomization volsync
    flux -n volsync-system {{ state }} helmrelease volsync
    kubectl -n volsync-system scale deployment volsync --replicas {{ if state != "suspend" { "1" } else { "0" } }}

[private]
render-local-ks ns ks:
    docker run --rm --volume "{{ justfile_directory() }}":/workspace ghcr.io/allenporter/flux-local:latest \
        build ks --namespace "{{ ns }}" --path "/workspace/kubernetes/flux/cluster" "{{ ks }}"
