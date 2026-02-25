set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

kubernetes_dir := justfile_dir() + '/kubernetes'

[private]
default:
    just -l kube

[doc('Apply local Flux Kustomization')]
apply-ks ns ks:
    just kube render-local-ks "{{ ns }}" "{{ ks }}" \
        | kubectl apply --server-side --force-conflicts \
            --field-manager=kustomize-controller -f /dev/stdin

[doc('Browse a PVC')]
browse-pvc ns claim:
    kubectl browse-pvc -n "{{ ns }}" -i mirror.gcr.io/alpine:latest "{{ claim }}"

[doc('Cleanup ReplicationDestination artifacts')]
cleanup-rdst ns app:
    if kubectl -n "{{ ns }}" get hr "{{ app }}" >/dev/null 2>&1 \
        || kubectl -n "{{ ns }}" get ks "{{ app }}" >/dev/null 2>&1; then \
        echo "Refusing cleanup-rdst: {{ ns }}/{{ app }} still deployed"; exit 2; \
    fi
    kubectl -n "{{ ns }}" delete --ignore-not-found \
        replicationdestination.volsync.backube/{{ app }}-dst
    kubectl -n "{{ ns }}" get volumesnapshot.snapshot.storage.k8s.io -o name 2>/dev/null \
        | grep -E "volsync-{{ app }}-dst-dest" \
        | xargs -r kubectl -n "{{ ns }}" delete --ignore-not-found || true
    kubectl -n "{{ ns }}" get \
        replicationdestination.volsync.backube,volumesnapshot.snapshot.storage.k8s.io \
        2>/dev/null \
        | grep -Ei "{{ app }}-dst|volsync-{{ app }}-dst-dest" || true

[doc('Delete local Flux Kustomization')]
delete-ks ns ks:
    just kube render-local-ks "{{ ns }}" "{{ ks }}" | kubectl delete -f /dev/stdin

[doc('Open a shell on a node')]
node-shell node:
    kubectl debug node/{{ node }} -n default -it \
        --image="mirror.gcr.io/alpine:latest" --profile sysadmin
    kubectl delete pod -n default -l app.kubernetes.io/managed-by=kubectl-debug

[doc('Prune pods in Failed, Pending, or Succeeded state')]
prune-pods:
    for phase in Failed Pending Succeeded; do \
        kubectl delete pods -A --field-selector status.phase="$phase" --ignore-not-found=true; \
    done

[doc('Snapshot all VolSync-backed PVCs')]
snapshot:
    kubectl get replicationsources --no-headers -A | while read -r ns name _; do \
        kubectl -n "$ns" patch replicationsources "$name" --type merge \
            --patch "{\"spec\":{\"trigger\":{\"manual\":\"$(date +%s)\"}}}"; \
    done

[doc('Snapshot VolSync-backed PVC for a specific app')]
snapshot-app ns app:
    kubectl -n "{{ ns }}" patch replicationsources/{{ app }} --type merge \
        --patch "{\"spec\":{\"trigger\":{\"manual\":\"$(date +%s)\"}}}"
    until kubectl -n "{{ ns }}" get job/volsync-src-{{ app }} &>/dev/null; do sleep 5; done
    kubectl -n "{{ ns }}" wait job/volsync-src-{{ app }} --for=condition=complete --timeout=120m

[doc('Suspend or resume Keda ScaledObjects')]
keda state:
    kubectl get scaledobjects --no-headers -A | while read -r ns name _; do \
        pause='autoscaling.keda.sh/paused{{ if state != "suspend" { "-" } else { "=true" } }}'; \
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite \
            so "$name" "$pause"; \
    done

[doc('Suspend or resume VolSync')]
volsync state:
    if [[ "{{ state }}" != "suspend" && "{{ state }}" != "resume" ]]; then \
        echo "state must be suspend or resume" >&2; exit 1; \
    fi
    flux -n volsync-system {{ state }} kustomization volsync
    flux -n volsync-system {{ state }} helmrelease volsync
    kubectl -n volsync-system scale deployment volsync \
        --replicas {{ if state != "suspend" { "1" } else { "0" } }}

[doc('Sync ExternalSecrets')]
sync-es:
    kubectl get es --no-headers -A | while read -r ns name _; do \
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite \
            es "$name" force-sync="$(date +%s)"; \
    done

[doc('Sync GitRepositories')]
sync-git:
    kubectl get gitrepo --no-headers -A | while read -r ns name _; do \
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite \
            gitrepo "$name" reconcile.fluxcd.io/requestedAt="$(date +%s)"; \
    done

[doc('Sync HelmReleases')]
sync-hr:
    kubectl get hr --no-headers -A | while read -r ns name _; do \
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite \
            hr "$name" \
            reconcile.fluxcd.io/requestedAt="$(date +%s)" \
            reconcile.fluxcd.io/forceAt="$(date +%s)"; \
    done

[doc('Sync Kustomizations')]
sync-ks:
    kubectl get ks --no-headers -A | while read -r ns name _; do \
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite \
            ks "$name" reconcile.fluxcd.io/requestedAt="$(date +%s)"; \
    done

[doc('Sync OCIRepositories')]
sync-oci:
    kubectl get ocirepo --no-headers -A | while read -r ns name _; do \
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite \
            ocirepo "$name" reconcile.fluxcd.io/requestedAt="$(date +%s)"; \
    done

[doc('View a Secret')]
view-secret ns secret:
    kubectl view-secret -n "{{ ns }}" "{{ secret }}"

[private]
render-local-ks ns ks:
    flux-local build ks --namespace "{{ ns }}" \
        --path "{{ kubernetes_dir }}/flux/cluster" "{{ ks }}"
