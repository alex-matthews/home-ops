#!/usr/bin/env bash

set -euo pipefail

# Set default values for the 'gum log' command
readonly LOG_ARGS=("log" "--time=rfc3339" "--formatter=text" "--structured" "--level")

# Talos requires the nodes to be 'Ready=False' before applying resources
function wait_for_nodes() {
    gum "${LOG_ARGS[@]}" debug "Waiting for nodes to be available"

    # Skip waiting if all nodes are 'Ready=True'
    if kubectl wait nodes --for=condition=Ready=True --all --timeout=10s &>/dev/null; then
        gum "${LOG_ARGS[@]}" info "Nodes are available and ready, skipping wait for nodes"
        return
    fi

    # Wait for all nodes to be 'Ready=False'
    until kubectl wait nodes --for=condition=Ready=False --all --timeout=10s &>/dev/null; do
        gum "${LOG_ARGS[@]}" info "Nodes are not available, waiting for nodes to be available. Retrying in 10 seconds..."
        sleep 10
    done
}

# Applications in the helmfile require Prometheus custom resources (e.g. servicemonitors)
function apply_prometheus_crds() {
    gum "${LOG_ARGS[@]}" debug "Applying Prometheus CRDs"

    # renovate: datasource=github-releases depName=prometheus-operator/prometheus-operator
    local -r version=v0.80.0
    local resources crds

    # Fetch resources using kustomize build
    if ! resources=$(kustomize build "https://github.com/prometheus-operator/prometheus-operator/?ref=${version}" 2>/dev/null) || [[ -z "${resources}" ]]; then
        gum "${LOG_ARGS[@]}" fatal "Failed to fetch Prometheus CRDs, check the version or the repository URL"
    fi

    # Extract only CustomResourceDefinitions
    if ! crds=$(echo "${resources}" | yq '. | select(.kind == "CustomResourceDefinition")' 2>/dev/null) || [[ -z "${crds}" ]]; then
        gum "${LOG_ARGS[@]}" fatal "No CustomResourceDefinitions found in the fetched resources"
    fi

    # Check if the CRDs are already applied
    if echo "${crds}" | kubectl diff --filename - &>/dev/null; then
        gum "${LOG_ARGS[@]}" info "Prometheus CRDs are up-to-date"
        return
    fi

    # Apply the CRDs
    if echo "${crds}" | kubectl apply --server-side --filename - &>/dev/null; then
        gum "${LOG_ARGS[@]}" info "Prometheus CRDs applied successfully"
    else
        gum "${LOG_ARGS[@]}" fatal "Failed to apply Prometheus CRDs"
    fi
}

# The application namespaces are created before applying the resources
function apply_namespaces() {
    gum "${LOG_ARGS[@]}" debug "Applying namespaces"

    local -r apps_dir="${KUBERNETES_DIR}/apps"

    if [[ ! -d "${apps_dir}" ]]; then
        gum "${LOG_ARGS[@]}" fatal "Directory does not exist" directory "${apps_dir}"
    fi

    # Apply namespaces if they do not exist
    for app in "${apps_dir}"/*/; do
        namespace=$(basename "${app}")

        if kubectl get namespace "${namespace}" &>/dev/null; then
            gum "${LOG_ARGS[@]}" info "Namespace resource is up-to-date" resource "${namespace}"
            continue
        fi

        if kubectl create namespace "${namespace}" --dry-run=client --output=yaml \
            | kubectl apply --server-side --filename - &>/dev/null;
        then
            gum "${LOG_ARGS[@]}" info "Namespace resource applied" resource "${namespace}"
        else
            gum "${LOG_ARGS[@]}" fatal "Failed to apply namespace resource" resource "${namespace}"
        fi
    done
}

# Foundational secrets to be applied before the helmfile charts are installed
function apply_foundational_secrets() {
    gum "${LOG_ARGS[@]}" debug "Applying foundational secrets"

    local -r secrets_file="${KUBERNETES_DIR}/bootstrap/apps/resources/secrets.yaml.tpl"
    local resources

    if [[ ! -f "${secrets_file}" ]]; then
        gum "${LOG_ARGS[@]}" fatal "File does not exist" file "${secrets_file}"
    fi

    # Hydrate secrets template using the 'op inject' command
    if ! resources=$(op inject --in-file "${secrets_file}" 2>/dev/null) || [[ -z "${resources}" ]]; then
        gum "${LOG_ARGS[@]}" fatal "Failed to inject secrets" file "${secrets_file}"
    fi

    # Check if the resources are up-to-date
    if echo "${resources}" | kubectl diff --filename - &>/dev/null; then
        gum "${LOG_ARGS[@]}" info "Foundational secrets are up-to-date"
        return
    fi

    # Apply secrets
    if echo "${resources}" | kubectl apply --server-side --filename - &>/dev/null; then
        gum "${LOG_ARGS[@]}" info "Foundational secrets applied"
    else
        gum "${LOG_ARGS[@]}" fatal "Failed to apply foundational secrets"
    fi
}

# ConfigMaps to be applied before the helmfile charts are installed
function apply_configmaps() {
    gum "${LOG_ARGS[@]}" debug "Applying ConfigMaps"

    local -r configmaps=(
        "${KUBERNETES_DIR}/flux/components/common/cluster-settings.yaml"
    )

    for configmap in "${configmaps[@]}"; do
        if [ ! -f "${configmap}" ]; then
            gum "${LOG_ARGS[@]}" warn "File does not exist" file "${configmap}"
            continue
        fi
        if kubectl --namespace flux-system diff --filename "${configmap}" &>/dev/null; then
            gum "${LOG_ARGS[@]}" info "ConfigMap resource is up-to-date" resource "$(basename "${configmap}" ".yaml")"
            continue
        fi
        if kubectl --namespace flux-system apply --server-side --filename "${configmap}" &>/dev/null; then
            gum "${LOG_ARGS[@]}" info "ConfigMap resource applied successfully" resource "$(basename "${configmap}" ".yaml")"
        else
            gum "${LOG_ARGS[@]}" fatal "Failed to apply ConfigMap resource" resource "$(basename "${configmap}" ".yaml")"
        fi
    done
}

# SOPS secrets to be applied before the helmfile charts are installed
function apply_sops_secrets() {
    gum "${LOG_ARGS[@]}" debug "Applying SOPS secrets"

    local -r secrets=(
        "${KUBERNETES_DIR}/flux/components/common/cluster-secrets.sops.yaml"
    )

    for secret in "${secrets[@]}"; do
        if [ ! -f "${secret}" ]; then
            gum "${LOG_ARGS[@]}" warn "File does not exist" file "${secret}"
            continue
        fi
        if sops exec-file "${secret}" "kubectl --namespace flux-system diff --filename {}" &>/dev/null; then
            gum "${LOG_ARGS[@]}" info "Secret resource is up-to-date" resource "$(basename "${secret}" ".yaml")"
            continue
        fi
        if sops exec-file "${secret}" "kubectl --namespace flux-system apply --server-side --filename {}" &>/dev/null; then
            gum "${LOG_ARGS[@]}" info "Secret resource applied successfully" resource "$(basename "${secret}" ".yaml")"
        else
            gum "${LOG_ARGS[@]}" fatal "Failed to apply secret resource" resource "$(basename "${secret}" ".yaml")"
        fi
    done
}

# Disks in use by rook-ceph must be wiped before Rook is installed
function wipe_rook_disks() {
    gum "${LOG_ARGS[@]}" debug "Wiping Rook disks"

    # Skip disk wipe if Rook is detected running in the cluster
    if kubectl --namespace rook-ceph get kustomization rook-ceph &>/dev/null; then
        gum "${LOG_ARGS[@]}" warn "Rook is detected running in the cluster, skipping disk wipe"
        return
    fi

    if ! nodes=$(talosctl config info --output json 2>/dev/null | jq --raw-output '.nodes | join(" ")') || [[ -z "${nodes}" ]]; then
        gum "${LOG_ARGS[@]}" fatal "No Talos nodes found"
    fi

    gum "${LOG_ARGS[@]}" debug "Discovered Talos nodes" nodes "${nodes}"

    # Hardcoded disk path
    disk="/dev/nvme0n1"

    # Wipe the specified disk on each node
    for node in ${nodes}; do
        if ! talosctl --nodes "${node}" get disks --output json | jq --exit-status --raw-output \
            --arg disk "${disk}" 'select(.metadata.dev_path == $disk)' &>/dev/null; then
            gum "${LOG_ARGS[@]}" warn "Disk ${disk} not found on node, skipping" node "${node}"
            continue
        fi

        gum "${LOG_ARGS[@]}" debug "Discovered Talos node and disk" node "${node}" disk "${disk}"

        if talosctl --nodes "${node}" wipe disk "${disk}" &>/dev/null; then
            gum "${LOG_ARGS[@]}" info "Disk wiped" node "${node}" disk "${disk}"
        else
            gum "${LOG_ARGS[@]}" fatal "Failed to wipe disk" node "${node}" disk "${disk}"
        fi
    done
}

function main() {
    wait_for_nodes
    apply_prometheus_crds
    apply_namespaces
    apply_foundational_secrets
    apply_configmaps
    apply_sops_secrets
    wipe_rook_disks
}

main "$@"
