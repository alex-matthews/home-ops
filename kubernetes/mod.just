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

[doc("Delete a retired app's backups from every repository with kopia; report by default (ADR-0005)")]
[positional-arguments]
retire-backups app delete="false":
    app="$1"; mode="${2:-false}"; ns="default"; label="kopiur.home-operations.com"
    [[ "$app" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]] || { echo "refusing: app must be a DNS label" >&2; exit 2; }
    read_json() { local out; out=$(kubectl get "$@" -o json) || { echo "refusing: read failed: kubectl get $*" >&2; exit 1; }; printf '%s' "$out"; }
    # Guards, re-run before every repository: the app and its PVC are gone and no live policy resolves to its identity.
    guard() {
        local n
        n=$(read_json kustomization -A | jq -r --arg a "$app" '[.items[] | select(.metadata.name == $a)] | length')
        [ "$n" = "0" ] || { echo "refusing: a Flux Kustomization named $app exists; remove the app first" >&2; exit 1; }
        n=$(read_json pvc -n "$ns" | jq -r --arg a "$app" '[.items[] | select(.metadata.name == $a)] | length')
        [ "$n" = "0" ] || { echo "refusing: PVC $ns/$app still exists; the app is not retired" >&2; exit 1; }
        n=$(read_json snapshotpolicy -A | jq -r --arg a "$app" --arg ns "$ns" '[.items[] | .status.resolved.identity? // empty | select(.hostname == $ns and .sourcePath == ("/pvc/" + $a))] | length')
        [ "$n" = "0" ] || { echo "refusing: $n live policies resolve to $ns:/pvc/$app" >&2; exit 1; }
    }
    guard
    # Every ClusterRepository must be Ready on an S3 backend; the recipe connects kopia with the same spec.
    repos=$(read_json clusterrepository | jq -c '[.items[] | {name: .metadata.name, uid: .metadata.uid, s3: .spec.backend.s3, ready: (([.status.conditions[]? | select(.type == "Ready")] | .[0].status) // "Unknown"), refreshed: (.status.catalog.lastRefreshAt // "never")}]')
    jq -e 'length > 0 and all(.[]; .ready == "True" and .s3 != null)' <<< "$repos" >/dev/null || { echo "refusing: every ClusterRepository must be Ready with an S3 backend" >&2; jq -r '.[] | "  \(.name): ready=\(.ready)"' <<< "$repos" >&2; exit 1; }
    # Discovered rows for the identity, grouped by repository. An unknown repository UID or two usernames on one repository is a stop.
    rows() {
        read_json snapshot."$label" -n "$ns" | jq -c --arg a "$app" --arg ns "$ns" --arg label "$label" --argjson repos "$repos" '
            [.items[] | select(.status.origin == "discovered")
                | select(.status.snapshot.identity.hostname == $ns and .status.snapshot.identity.sourcePath == ("/pvc/" + $a))
                | {uid: .metadata.labels[$label + "/repository-uid"], user: .status.snapshot.identity.username, id: .status.snapshot.kopiaSnapshotID, size: (.status.stats.sizeBytes // 0), end: (.status.timing.endTime // "")}]
            | if any(.[]; .uid as $u | ($repos | map(.uid) | index($u)) == null) then error("a row carries a repository uid that no ClusterRepository has") else . end
            | group_by(.uid) | map({uid: .[0].uid, name: (.[0].uid as $u | $repos[] | select(.uid == $u) | .name), users: (map(.user) | unique), n: length, ids: (map(.id) | sort), size: (map(.size) | add), newest: (map(.end) | max)})'
    }
    plan=$(rows)
    jq -e 'all(.[]; (.users | length) == 1)' <<< "$plan" >/dev/null || { echo "refusing: more than one username for $app on one repository; the lineage is ambiguous" >&2; exit 1; }
    total=$(jq 'map(.n) | add // 0' <<< "$plan")
    echo "$app: discovered rows per repository"
    jq -r --argjson plan "$plan" --arg ns "$ns" --arg a "$app" '.[] | . as $r | (first($plan[] | select(.uid == $r.uid)) // null) as $p
        | "  \(.name): \($p.n // 0) snapshots" + (if $p then " for \($p.users[0])@\($ns):/pvc/\($a), \($p.size / 1048576 | floor) MiB logical, newest \($p.newest[0:19])" else "" end) + "; catalog refreshed \(.refreshed[0:19])"' <<< "$repos"
    if [ "$mode" != "true" ]; then echo "report only (Kubernetes rows; nothing read from the repositories); rerun with delete=true to delete these $total snapshots with kopia"; exit 0; fi
    [ "$total" != "0" ] || { echo "nothing to delete"; exit 0; }
    # Delete mode. Preflight every write and the credentials before the first one.
    for res in "clusterrepositories.$label"; do
        kubectl auth can-i patch "$res" >/dev/null 2>&1 || { echo "refusing: this identity cannot patch $res; run under the administrative profile" >&2; exit 1; }
    done
    for name in $(jq -r '.[].name' <<< "$plan"); do
        op read "op://kubernetes/kopiur-$name/KOPIA_PASSWORD" >/dev/null || { echo "refusing: cannot read the kopiur-$name credentials from 1Password" >&2; exit 1; }
    done
    jq -r --arg ns "$ns" --arg a "$app" '.[] | "  \(.name): \(.n) snapshots for \(.users[0])@\($ns):/pvc/\($a)"' <<< "$plan"
    gum confirm "Delete these $total snapshots for $app from the repositories above with kopia? There is no undo." || exit 1
    run=$(date -u +%Y%m%dT%H%M%SZ)
    state="${XDG_STATE_HOME:-$HOME/.local/state}/home-ops"; mkdir -p "$state"; ledger="$state/retire-backups-$app-$run.log"
    work=$(mktemp -d "${TMPDIR:-/tmp}/retire-backups.XXXXXX")
    trap 'rc=$?; rm -rf "$work"; if [ "$rc" != "0" ]; then echo "stopped with exit $rc; state so far is in $ledger:" >&2; sed "s/^/  /" "$ledger" >&2; fi; exit $rc' EXIT
    echo "run $run for $app; plan: $(jq -c 'map({name, n, ids})' <<< "$plan")" >> "$ledger"
    # One repository at a time, each with fresh guards, a fresh row read, and the repository's own listing as the last word.
    for name in $(jq -r '.[].name' <<< "$plan"); do
        p=$(jq -c --arg n "$name" '.[] | select(.name == $n)' <<< "$plan")
        uid=$(jq -r .uid <<< "$p"); want=$(jq -c .ids <<< "$p"); source="$(jq -r '.users[0]' <<< "$p")@$ns:/pvc/$app"
        guard
        fresh=$(rows | jq -c --arg u "$uid" '(first(.[] | select(.uid == $u)) // {ids: []}).ids')
        [ "$fresh" = "$want" ] || { echo "$name: abort, rows changed since the plan was made; nothing deleted here" | tee -a "$ledger" >&2; exit 1; }
        args=$(jq -r --arg n "$name" '.[] | select(.name == $n) | .s3 | ["--bucket=\(.bucket)", (if .endpoint then "--endpoint=\(.endpoint)" else empty end), (if .region then "--region=\(.region)" else empty end), (if .prefix then "--prefix=\(.prefix)" else empty end), (if .tls.disableTls == true then "--disable-tls" else empty end)] | .[]' <<< "$repos")
        printf 'AWS_ACCESS_KEY_ID=op://kubernetes/kopiur-%s/AWS_ACCESS_KEY_ID\nAWS_SECRET_ACCESS_KEY=op://kubernetes/kopiur-%s/AWS_SECRET_ACCESS_KEY\nKOPIA_PASSWORD=op://kubernetes/kopiur-%s/KOPIA_PASSWORD\n' "$name" "$name" "$name" > "$work/$name.env"
        mkdir -p "$work/$name"
        echo "$name: deleting $(jq length <<< "$want") snapshots for $source" | tee -a "$ledger"
        # kopia writes the S3 keys into its config file, so the file lives in $work and dies with the trap.
        RB_SOURCE="$source" RB_WANT="$want" RB_ARGS="$args" RB_DIR="$work/$name" RB_LEDGER="$ledger" \
        op run --env-file="$work/$name.env" --no-masking -- bash -euo pipefail -c '
            k() { kopia --config-file="$RB_DIR/repository.config" --log-dir="$RB_DIR/logs" "$@"; }
            mapfile -t args <<< "$RB_ARGS"
            k repository connect s3 "${args[@]}" --no-persist-credentials --cache-directory="$RB_DIR/cache" >/dev/null 2>&1
            have=$(k snapshot list --all --json "$RB_SOURCE" | jq -c "map(.id) | sort")
            [ "$have" = "$RB_WANT" ] || { echo "abort: the repository lists $(jq length <<< "$have") snapshots for $RB_SOURCE and the rows say $(jq length <<< "$RB_WANT"); nothing deleted" | tee -a "$RB_LEDGER" >&2; exit 1; }
            k snapshot delete --all-snapshots-for-source --delete "$RB_SOURCE" >/dev/null
            echo "deleted $(jq length <<< "$RB_WANT") snapshots for $RB_SOURCE at $(date -u +%FT%TZ): $RB_WANT" >> "$RB_LEDGER"
            left=$(k snapshot list --all --json "$RB_SOURCE" 2>/dev/null || true); left=$(jq -c "map(.id)" <<< "${left:-[]}")
            [ "$left" = "[]" ] || { echo "verify failed: $RB_SOURCE still lists $left" | tee -a "$RB_LEDGER" >&2; exit 1; }
            echo "verified: $RB_SOURCE lists no snapshots" >> "$RB_LEDGER"
        '
        echo "$name: deleted and verified empty"
        # Ask kopiur to rescan so the rows expire now rather than at the next refresh; the token is honoured by equality.
        token=$(date -u +%FT%TZ)
        kubectl annotate clusterrepository "$name" "$label/catalog-scan-requested-at=$token" --overwrite >/dev/null
        honored=""
        for i in $(seq 1 120); do
            honored=$(read_json clusterrepository "$name" | jq -r '.status.catalog.scanRequestHonored // ""')
            [ "$honored" = "$token" ] && break; sleep 5
        done
        if [ "$honored" != "$token" ]; then echo "$name: catalog scan not honoured within 10 minutes; rows expire at the next scan" | tee -a "$ledger"; continue; fi
        remaining=$(rows | jq --arg u "$uid" '(first(.[] | select(.uid == $u)) // {n: 0}).n')
        echo "$name: catalog scan honoured, $remaining rows remain for $app" | tee -a "$ledger"
    done
    echo "done: $total snapshots for $app deleted; ledger $ledger; space returns at each repository's next full maintenance"

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
