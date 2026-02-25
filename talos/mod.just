set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

talos_dir := justfile_dir() + '/talos'
controller := `talosctl config info -o yaml | yq -e '.endpoints[0]'`

[private]
default:
    just -l talos

[doc('Apply Talos config to a node')]
apply-node node *args:
    just talos render-config "{{ node }}" \
        | talosctl -n "{{ node }}" apply-config -f /dev/stdin {{ args }}

[doc('Show Talos client certificate expiry')]
cert-check:
    days_left="$(just talos cert-days-left)"; \
    not_after="$(talosctl config info -o yaml | yq -r '.certNotAfter')"; \
    echo "certNotAfter=$not_after daysLeft=$days_left"; \
    (( days_left >= 0 )) || { echo "Talos client certificate has expired" >&2; exit 2; }

[doc('Renew Talos client certificate safely')]
cert-renew:
    days_left="$(just talos cert-days-left)"; \
    if (( days_left > 30 )); then \
        echo "Skipping renewal: 30d threshold not reached ($days_left days left)"; \
        exit 0; \
    fi
    tmpd="$(mktemp -d)"; \
    trap 'rm -rf "$tmpd"' EXIT; \
    new="$tmpd/talosconfig.new"
    nodes="$(talosctl config info -o yaml | yq -r '.nodes[]' | tr '\n' ' ')"; \
    endpoints="$(talosctl config info -o yaml | yq -r '.endpoints[]' | tr '\n' ' ')"
    talosctl -n "{{ controller }}" config new "$new" \
        --roles os:admin --crt-ttl "8760h"
    talosctl --talosconfig "$new" config node $nodes
    talosctl --talosconfig "$new" config endpoint $endpoints
    talosctl --talosconfig "$new" -n "{{ controller }}" version >/dev/null
    cp talosconfig "talosconfig.bak.$(date +%Y%m%d%H%M%S)"
    mv "$new" talosconfig
    talosctl config info -o yaml | yq -r '"certNotAfter=" + .certNotAfter'

[doc('Download Talos machine image')]
download-image version schematic:
    sid="{{ schematic }}"; sid="${sid:0:8}"; \
    gum spin --title "Downloading Talos {{ version }} ..." -- \
        curl -sfL --remove-on-error --retry 5 --retry-delay 5 --retry-all-errors \
            -o "{{ talos_dir }}/talos-{{ version }}-$sid.iso" \
            "https://factory.talos.dev/image/{{ schematic }}/{{ version }}/metal-amd64.iso"
    just log info \
        "Downloaded Talos" version "{{ version }}" schematic "{{ schematic }}"

[doc('Generate schematic ID from Talos schematic')]
gen-schematic-id:
    curl -sX POST --data-binary @<(just template "{{ talos_dir }}/schematic.yaml.j2") \
        "https://factory.talos.dev/schematics" \
        | jq -r '.id'

[doc('Reboot a node')]
reboot-node node:
    gum confirm "Reboot node {{ node }}?" --default="No" && \
        talosctl -n "{{ node }}" reboot -m powercycle || exit 0

[doc('Render Talos config for a node')]
render-config node:
    export IS_CONTROLLER="$(just talos machine-controller "{{ node }}")"; \
    talosctl machineconfig patch <(just template "{{ talos_dir }}/machineconfig.yaml.j2") \
        -p @<(just template "{{ talos_dir }}/nodes/{{ node }}.yaml.j2")

[doc('Reset a node (--force for full wipe)')]
reset-node node *args:
    mode="maintenance"; pass=(); \
    wipe=(--system-labels-to-wipe STATE --system-labels-to-wipe EPHEMERAL)
    for arg in {{ args }}; do \
        if [[ "$arg" == "--force" ]]; then \
            mode="full"; wipe=(); \
        else \
            pass+=("$arg"); \
        fi; \
    done
    gum confirm "Reset node {{ node }} (mode: $mode)?" --default="No" && \
        talosctl -n "{{ node }}" reset --reboot --wait=false --graceful=false \
            "${wipe[@]}" "${pass[@]}" || exit 0

[doc('Reset all nodes (--force for full wipe)')]
reset-cluster *args:
    mode="maintenance"; pass=(); \
    wipe=(--system-labels-to-wipe STATE --system-labels-to-wipe EPHEMERAL)
    for arg in {{ args }}; do \
        if [[ "$arg" == "--force" ]]; then \
            mode="full"; wipe=(); \
        else \
            pass+=("$arg"); \
        fi; \
    done
    gum confirm "Reset all nodes (mode: $mode)?" --default="No" && \
        for node in $(talosctl config info -o yaml | yq -r '.nodes[]'); do \
            talosctl -n "$node" reset --reboot --wait=false --graceful=false \
                "${wipe[@]}" "${pass[@]}"; \
        done || exit 0

[doc('Shutdown a node')]
shutdown-node node *args:
    gum confirm "Shutdown node {{ node }}?" --default="No" && \
        talosctl -n "{{ node }}" shutdown --force {{ args }} || exit 0

[doc('Upgrade Kubernetes version on the cluster')]
upgrade-k8s version:
    talosctl -n "{{ controller }}" upgrade-k8s --to {{ version }}

[doc('Upgrade Talos version on a node')]
upgrade-node node *args:
    talosctl -n "{{ node }}" upgrade \
        -i "$(just talos machine-image)" -m powercycle --timeout=10m {{ args }}

[private]
machine-controller node:
    just template "{{ talos_dir }}/nodes/{{ node }}.yaml.j2" \
        | yq -e 'select(.machine) | (.machine.type == "controlplane") // ""'

[private]
cert-days-left:
    not_after="$(talosctl config info -o yaml | yq -r '.certNotAfter')"; \
    jq -nr --arg d "$not_after" '(($d + "T00:00:00Z" | fromdateiso8601) - now) / 86400 | floor'

[private]
machine-image:
    just template "{{ talos_dir }}/machineconfig.yaml.j2" \
        | yq -e 'select(.machine) | .machine.install.image'
