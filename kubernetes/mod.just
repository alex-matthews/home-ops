set default-list
set default-script
set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

[doc('Apply local Flux Kustomization')]
apply-ks ns ks:
    just kube render-local-ks "{{ ns }}" "{{ ks }}" | kubectl apply --server-side --force-conflicts --field-manager=kustomize-controller -f -

[doc('Browse a PVC')]
browse-pvc ns claim:
    kubectl run -n {{ ns }} browse-pvc-{{ claim }} -it --rm --restart=Never \
        --image=mirror.gcr.io/alpine:latest \
        --overrides='{"spec":{"containers":[{"name":"browse-pvc-{{ claim }}","image":"mirror.gcr.io/alpine:latest","stdin":true,"tty":true,"command":["/bin/sh"],"workingDir":"/mnt","volumeMounts":[{"mountPath":"/mnt","name":"data"}]}],"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"{{ claim }}"}}]}}'

[doc('Debug a node')]
debug-node node:
    trap 'kubectl delete pod -n default -l app.kubernetes.io/managed-by=kubectl-debug --field-selector spec.nodeName={{ node }} --ignore-not-found --wait=false' EXIT
    kubectl debug node/{{ node }} -n default -it --image=mirror.gcr.io/alpine:latest --profile=sysadmin

[doc('Delete local Flux Kustomization')]
delete-ks ns ks:
    just kube render-local-ks "{{ ns }}" "{{ ks }}" | kubectl delete -f -

[doc('Mint the read-only session kubeconfig from a bounded ServiceAccount token (#2021)')]
readonly-token duration="8h":
    root="{{ justfile_dir() }}"; admin="$root/kubeconfig"; out="$root/kubeconfig-readonly"
    [ -f "$admin" ] || { echo "refusing: $admin not found; the administrative kubeconfig mints the token, and credential files live in the main checkout, not a worktree" >&2; exit 1; }
    # No-op while the current token has more than an hour left; the expiry is read from the JWT, no network needed.
    now=$(date +%s); exp=0
    if [ -f "$out" ]; then
        exp=$(yq -r '.users[0].user.token // ""' "$out" | jq -R 'split(".")[1] // "" | . + "=" * ((4 - length % 4) % 4) | @base64d | fromjson | .exp // 0' 2>/dev/null || echo 0)
    fi
    if [ "$exp" -gt $((now + 3600)) ]; then echo "read-only token valid for another $(( (exp - now) / 60 )) minutes; nothing to do"; exit 0; fi
    token=$(kubectl --kubeconfig "$admin" create token agent-readonly -n kube-system --duration "{{ duration }}")
    server=$(yq -r '.clusters[0].cluster.server' "$admin"); ca=$(yq -r '.clusters[0].cluster."certificate-authority-data"' "$admin")
    umask 077
    TOKEN="$token" SERVER="$server" CA="$ca" yq -n '{"apiVersion": "v1", "kind": "Config", "current-context": "main-readonly",
        "clusters": [{"name": "main", "cluster": {"server": env(SERVER), "certificate-authority-data": env(CA)}}],
        "users": [{"name": "agent-readonly", "user": {"token": env(TOKEN)}}],
        "contexts": [{"name": "main-readonly", "context": {"cluster": "main", "user": "agent-readonly"}}]}' > "$out.tmp"
    mv "$out.tmp" "$out"
    echo "read-only token minted for {{ duration }}; $out written"

[doc('Prune pods in Failed, Pending, or Succeeded state')]
prune-pods:
    for phase in Failed Pending Succeeded; do
        kubectl delete pods -A --field-selector status.phase="$phase" --ignore-not-found=true
    done

[arg('resource', pattern='hr|ks|gitrepo|ocirepo|es')]
[doc('Sync a resource')]
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

[private]
render-local-ks ns ks:
    flate build ks --namespace "{{ ns }}" --output yaml "{{ ks }}"
