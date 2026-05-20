set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

[private]
default:
    just -l talos

[confirm('Apply Talos config to ' + node + ' [y|N] ?')]
[doc('Apply Talos config to a node')]
apply-node node *args:
    just talos render-config "{{ node }}" | talosctl -n "{{ node }}" apply-config -f /dev/stdin {{ args }}

[doc('Show Talos client certificate expiry')]
[script]
cert-check:
    days_left="$(just talos cert-days-left)"
    not_after="$(talosctl config info -o yaml | yq -r '.certNotAfter')"
    echo "certNotAfter=$not_after daysLeft=$days_left"
    (( days_left >= 0 )) || { echo "Talos client certificate has expired" >&2; exit 2; }

[confirm('Renew Talos client certificate [y|N] ?')]
[doc('Renew Talos client certificate safely')]
[script]
cert-renew:
    days_left="$(just talos cert-days-left)"
    if (( days_left > 30 )); then
        echo "Skipping renewal: 30d threshold not reached ($days_left days left)"
        exit 0
    fi
    endpoint="$(just talos talos-endpoint)"
    tmpd="$(mktemp -d)"
    trap 'rm -rf "$tmpd"' EXIT
    new="$tmpd/talosconfig.new"
    nodes=()
    while IFS= read -r node; do nodes+=("$node"); done < <(talosctl config info -o yaml | yq -r '.nodes[]')
    endpoints=()
    while IFS= read -r endpoint; do endpoints+=("$endpoint"); done < <(talosctl config info -o yaml | yq -r '.endpoints[]')
    talosctl -n "$endpoint" config new "$new" \
        --roles os:admin --crt-ttl "8760h"
    talosctl --talosconfig "$new" config node "${nodes[@]}"
    talosctl --talosconfig "$new" config endpoint "${endpoints[@]}"
    talosctl --talosconfig "$new" -n "$endpoint" version >/dev/null
    cp talosconfig "talosconfig.bak.$(date +%Y%m%d%H%M%S)"
    mv "$new" talosconfig
    talosctl config info -o yaml | yq -r '"certNotAfter=" + .certNotAfter'

[doc('Download Talos machine image')]
[script]
download-image version:
    export SCHEMATIC="$(just talos schematic-id)"
    curl -fL --remove-on-error --retry 5 --retry-delay 5 --retry-all-errors --progress-bar \
        -o "{{ source_directory() }}/talos-{{ version }}-${SCHEMATIC:0:8}.iso" \
        "https://factory.talos.dev/image/${SCHEMATIC}/{{ version }}/metal-amd64.iso"
    just log info "Downloaded Talos" version "{{ version }}" schematic "${SCHEMATIC}"

[confirm('Reboot node ' + node + ' [y|N] ?')]
[doc('Reboot a node')]
reboot-node node:
    talosctl -n {{ node }} reboot -m powercycle

[doc('Render Talos config for a node')]
[script]
render-config node:
    export CONTROLPLANE="$(just talos machine-controller {{ node }})"
    export IS_CONTROLLER="$CONTROLPLANE"
    export SCHEMATIC="$(just talos schematic-id)"
    talosctl machineconfig patch <(just template "{{ source_directory() }}/machineconfig.yaml.j2") \
        -p @<(just template "{{ source_directory() }}/nodes/{{ node }}.yaml.j2")

[confirm('Reset all nodes (--force for full wipe) [y|N] ?')]
[doc('Reset all nodes (--force for full wipe)')]
[script]
reset-cluster *args:
    mode="maintenance"; pass=()
    wipe=(--system-labels-to-wipe STATE --system-labels-to-wipe EPHEMERAL)
    for arg in {{ args }}; do
        if [[ "$arg" == "--force" ]]; then
            mode="full"; wipe=()
        else
            pass+=("$arg")
        fi
    done
    for node in $(talosctl config info -o yaml | yq -r '.nodes[]'); do
        just log info "Resetting node" node "$node" mode "$mode"
        talosctl -n "$node" reset --reboot --wait=false --graceful=false "${wipe[@]}" "${pass[@]}"
    done

[confirm('Reset node ' + node + ' (--force for full wipe) [y|N] ?')]
[doc('Reset a node (--force for full wipe)')]
[script]
reset-node node *args:
    mode="maintenance"; pass=()
    wipe=(--system-labels-to-wipe STATE --system-labels-to-wipe EPHEMERAL)
    for arg in {{ args }}; do
        if [[ "$arg" == "--force" ]]; then
            mode="full"; wipe=()
        else
            pass+=("$arg")
        fi
    done
    just log info "Resetting node" node "{{ node }}" mode "$mode"
    talosctl -n "{{ node }}" reset --reboot --wait=false --graceful=false "${wipe[@]}" "${pass[@]}"

[confirm('Shutdown node ' + node + ' [y|N] ?')]
[doc('Shutdown a node')]
shutdown-node node *args:
    talosctl -n "{{ node }}" shutdown --force {{ args }}

[confirm('Upgrade Kubernetes to ' + version + ' [y|N] ?')]
[doc('Upgrade Kubernetes version on the cluster')]
upgrade-k8s version:
    talosctl -n "$(just talos talos-endpoint)" upgrade-k8s --to {{ version }}

[confirm('Upgrade node ' + node + ' [y|N] ?')]
[doc('Upgrade Talos version on a node')]
upgrade-node node *args:
    talosctl -n "{{ node }}" upgrade -i "$(just talos machine-image)" -m powercycle --timeout=10m {{ args }}

[private]
[script]
cert-days-left:
    not_after="$(talosctl config info -o yaml | yq -r '.certNotAfter')"
    jq -nr --arg d "$not_after" '(($d + "T00:00:00Z" | fromdateiso8601) - now) / 86400 | floor'

[private]
machine-controller node:
    just template "{{ source_directory() }}/nodes/{{ node }}.yaml.j2" | yq -e 'select(.machine) | (.machine.type == "controlplane") // ""'

[private]
[script]
machine-image:
    export SCHEMATIC="$(just talos schematic-id)"
    just template "{{ source_directory() }}/machineconfig.yaml.j2" | yq -e 'select(.machine) | .machine.install.image'

[private]
schematic-id:
    curl -sX POST --data-binary @<(just template "{{ source_directory() }}/schematic.yaml.j2") "https://factory.talos.dev/schematics" | jq -r '.id'

[private]
talos-endpoint:
    talosctl config info -o yaml | yq -e '.endpoints[0]'
