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

[doc('Prune pods in Failed, Pending, or Succeeded state')]
prune-pods:
    for phase in Failed Pending Succeeded; do
        kubectl delete pods -A --field-selector status.phase="$phase" --ignore-not-found=true
    done

[doc("Retire a removed app's backups: report by default, delete with delete=true (ADR-0005)")]
retire-backups app delete="false":
    app="{{ app }}"; ns="default"; mode="{{ delete }}"
    label="kopiur.home-operations.com"
    # Guard: the app must be gone and nothing live may claim its identities.
    if kubectl get kustomization -A --field-selector metadata.name="$app" -o name 2>/dev/null | grep -q .; then
        echo "refusing: a Flux Kustomization named $app still exists; remove the app first" >&2; exit 1
    fi
    q_claimed='[.items[] | select((.status.resolved.identity.username // .metadata.name) as $u | $u == $a or $u == ($a + "-remote"))] | length'
    claimed=$(kubectl -n "$ns" get snapshotpolicy -o json | jq -r --arg a "$app" "$q_claimed")
    [ "$claimed" = "0" ] || { echo "refusing: $claimed live policies still claim $app's identities" >&2; exit 1; }
    # Inventory: discovered rows for the app's two identities, per repository.
    repos=$(kubectl get clusterrepository -o json | jq -c '[.items[] | {name: .metadata.name, uid: .metadata.uid}]')
    q_rows='[.items[] | select(.status.origin == "discovered") | select(.status.snapshot.identity.hostname == $ns and .status.snapshot.identity.sourcePath == ("/pvc/" + $a)) | select(.status.snapshot.identity.username == $a or .status.snapshot.identity.username == ($a + "-remote")) | {repo: (.metadata.labels[$label + "/repository-uid"] as $u | ($repos[] | select(.uid == $u) | .name)), user: .status.snapshot.identity.username, size: (.status.stats.sizeBytes // 0), end: (.status.timing.endTime // "")}]'
    rows=$(kubectl -n "$ns" get snapshot."$label" -o json | jq -c --arg a "$app" --arg ns "$ns" --arg label "$label" --argjson repos "$repos" "$q_rows")
    total=$(jq 'length' <<< "$rows")
    jq -r 'group_by(.repo)[] | "\(.[0].repo): \(length) snapshots, \(map(.size) | add / 1048576 | floor) MiB logical, newest \(map(.end) | max | .[0:19])"' <<< "$rows"
    if [ "$total" = "0" ]; then echo "nothing to retire: no discovered snapshots for $app"; exit 0; fi
    if [ "$mode" != "true" ]; then echo "report only; rerun with delete=true to delete these $total snapshots"; exit 0; fi
    # Delete mode: needs the administrative identity and a fresh confirmation.
    if ! kubectl auth can-i create snapshotpolicies."$label" -n "$ns" >/dev/null 2>&1; then
        echo "refusing: this identity cannot create policies; run under the administrative profile" >&2; exit 1
    fi
    gum confirm "Delete all $total retained snapshots for $app on both repositories?" || exit 1
    start=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    # Adopt: a throwaway policy per repository, identity pinned, no schedule, no retention
    # (absent retention never prunes; a present block would prune past the breaker).
    for repo in $(jq -r '[.[].repo] | unique[]' <<< "$rows"); do
        user=$(jq -r --arg r "$repo" '[.[] | select(.repo == $r) | .user] | unique[0]' <<< "$rows")
        want=$(jq -r --arg r "$repo" '[.[] | select(.repo == $r)] | length' <<< "$rows")
        pol="retire-$app-$repo"
        printf '%s\n' "apiVersion: kopiur.home-operations.com/v1alpha1" "kind: SnapshotPolicy" \
            "metadata: {name: $pol, namespace: $ns, labels: {app.kubernetes.io/managed-by: retire-backups}}" \
            "spec:" "  repository: {kind: ClusterRepository, name: $repo}" \
            "  identity: {username: $user, hostname: $ns}" "  sources: [{pvc: {name: $app}}]" \
            "  defaultDeletionPolicy: Delete" "  deletion: {onPolicyDelete: Delete}" | kubectl apply -f -
        got=0
        for i in $(seq 1 60); do
            got=$(kubectl -n "$ns" get snapshot."$label" -l "$label/config=$pol,$label/origin=adopted" -o name | wc -l | tr -d ' ')
            [ "$got" = "$want" ] && break; sleep 5
        done
        if [ "$got" != "$want" ]; then
            echo "abort: $repo adopted $got of $want; leaving the data untouched" >&2
            kubectl -n "$ns" patch snapshotpolicy "$pol" --type merge -p '{"spec":{"deletion":{"onPolicyDelete":"Retain"}}}'
            kubectl -n "$ns" delete snapshotpolicy "$pol"; exit 1
        fi
        echo "$repo: adopted $got of $want"
    done
    # Delete: removing the policies is the deletion; the breaker may hold a wave.
    kubectl -n "$ns" delete snapshotpolicy -l app.kubernetes.io/managed-by=retire-backups --wait=false
    q_left='[.items[] | select((.metadata.labels[$label + "/config"] // "") | startswith($p))] | length'
    q_held='[.items[] | select((.metadata.labels[$label + "/config"] // "") | startswith($p)) | .status.conditions[]? | select(.type == "DeletionHeld" and .status == "True") | .message] | first // ""'
    left=1
    for i in $(seq 1 360); do
        snaps=$(kubectl -n "$ns" get snapshot."$label" -o json)
        left=$(jq --arg label "$label" --arg p "retire-$app-" "$q_left" <<< "$snaps")
        [ "$left" = "0" ] && break
        held=$(jq -r --arg label "$label" --arg p "retire-$app-" "$q_held" <<< "$snaps")
        if [ -n "$held" ] && [ $((i % 12)) -eq 1 ]; then
            echo "held by the mass-deletion breaker; approve with the command in this message:"; sed 's/^/  /' <<< "$held"
        fi
        sleep 5
    done
    [ "$left" = "0" ] || { echo "timed out with $left snapshots still pending; nothing further was done" >&2; exit 1; }
    echo "delete batches since $start:"
    kubectl -n kopiur-system get jobs -l "$label/op=snapshot-delete-batch" -o json | jq -r --arg t "$start" '.items[] | select(.metadata.creationTimestamp >= $t) | "  \(.metadata.name): succeeded=\(.status.succeeded // 0) failed=\(.status.failed // 0)"'
    echo "done: $total snapshots for $app deleted; the catalog re-scans within a day and tonight's full maintenance reclaims the space"

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
