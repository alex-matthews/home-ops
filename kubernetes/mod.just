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
    kubectl run -n {{ ns }} browse-pvc-{{ claim }} -it --rm --restart=Never \
        --image=mirror.gcr.io/alpine:latest \
        --overrides='{"spec":{"containers":[{"name":"browse-pvc-{{ claim }}","image":"mirror.gcr.io/alpine:latest","stdin":true,"tty":true,"command":["/bin/sh"],"workingDir":"/mnt","volumeMounts":[{"mountPath":"/mnt","name":"data"}]}],"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"{{ claim }}"}}]}}'

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

[doc('Prune pods in Failed, Pending, or Succeeded state')]
[script]
prune-pods:
    for phase in Failed Pending Succeeded; do
        kubectl delete pods -A --field-selector status.phase="$phase" --ignore-not-found=true
    done

[doc('Preview Homepage locally')]
[script]
homepage-preview port="3000":
    if ! docker info >/dev/null 2>&1; then
        echo "Docker is not running. Start Colima or Docker Desktop, then re-run this preview."
        exit 1
    fi

    repo_dir="{{ justfile_directory() }}"
    app_dir="${repo_dir}/kubernetes/apps/default/homepage/app"
    config_dir="${app_dir}/resources"
    mkdir -p "${repo_dir}/.private"
    tmp_dir="$(mktemp -d "${repo_dir}/.private/homepage-preview.XXXXXX")"
    image="$(yq -r '.spec.values.controllers.homepage.containers.app.image | .repository + ":" + .tag' "${app_dir}/helmrelease.yaml")"

    cleanup() {
        rm -rf "${tmp_dir}"
    }
    trap cleanup EXIT

    cp "${config_dir}"/* "${tmp_dir}/"
    yq '.hideErrors = true' "${config_dir}/settings.yaml" > "${tmp_dir}/settings.yaml"

    docker run --rm \
        --name "homepage-preview-{{ port }}" \
        --pull missing \
        -p "127.0.0.1:{{ port }}:3000" \
        -e "HOMEPAGE_ALLOWED_HOSTS=localhost:{{ port }},127.0.0.1:{{ port }}" \
        -e "LOG_TARGETS=stdout" \
        -e "TZ=Pacific/Auckland" \
        -e "HOMEPAGE_VAR_PROWLARR_API_KEY=preview" \
        -e "HOMEPAGE_VAR_RADARR_API_KEY=preview" \
        -e "HOMEPAGE_VAR_RADARR_SE_API_KEY=preview" \
        -e "HOMEPAGE_VAR_SABNZBD_API_KEY=preview" \
        -e "HOMEPAGE_VAR_SEERR_API_KEY=preview" \
        -e "HOMEPAGE_VAR_SONARR_API_KEY=preview" \
        -e "HOMEPAGE_VAR_TAUTULLI_API_KEY=preview" \
        -v "${tmp_dir}:/app/config:ro" \
        "${image}"

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
            "force-sync=$(date +%s)" \
            "reconcile.fluxcd.io/requestedAt=$(date +%s)" \
            "reconcile.fluxcd.io/forceAt=$(date +%s)"
    done

[doc('View a secret')]
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
    flate build ks --namespace "{{ ns }}" --output yaml "{{ ks }}"
