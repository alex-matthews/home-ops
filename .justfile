#!/usr/bin/env -S just --justfile

set default-list
set default-script
set lazy
set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

# Bootstrap Recipes
[group('Bootstrap')]
mod bootstrap "bootstrap"

# Kube Recipes
[group('Kube')]
mod kube "kubernetes"

# Talos Recipes
[group('Talos')]
mod talos "talos"

# VolSync Recipes
[group('VolSync')]
mod volsync "volsync"

[private]
log lvl msg *args:
    gum log -t rfc3339 -s -l "{{ lvl }}" "{{ msg }}" {{ args }}

# op inject only when the render contains a 1Password reference, so
# secretless templates skip the authentication prompt entirely
[private]
template file *args:
    output=$(minijinja-cli "{{ file }}" {{ args }})
    if [[ "$output" == *"op://"* ]]; then
        op inject <<< "$output"
    else
        printf '%s\n' "$output"
    fi
