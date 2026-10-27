#!/usr/bin/env bash
# Model references. Offline: yq only.
#
# Fail when a client names a model LiteLLM does not serve, or one its virtual
# key does not allow. A missing field also fails: it means a client's config
# moved, not that it names no models.
#
# usage: model-references.sh
set -euo pipefail

tool() { mise exec -- "$@"; }

litellm=kubernetes/apps/ai/litellm/app
served="$(tool yq -N 'select(.kind == "LiteLLMModel") | .spec.modelName' "$litellm/litellmmodels.yaml")"
[ -n "$served" ] || { echo "no LiteLLMModel found in $litellm/litellmmodels.yaml" >&2; exit 2; }
# Each consumer declares its own key beside it.
keys=()
while IFS= read -r -d '' file; do
  keys+=("$file")
done < <(git grep -z -l -E '^kind:[[:space:]]*LiteLLMVirtualKey' -- kubernetes/apps)
[ "${#keys[@]}" -gt 0 ] || { echo "no LiteLLMVirtualKey found under kubernetes/apps" >&2; exit 2; }
# Keys are looked up by name, so a name used twice would merge two allowlists.
duplicates="$(tool yq -N 'select(.kind == "LiteLLMVirtualKey") | .metadata.name' "${keys[@]}" | sort | uniq -d)"
[ -z "$duplicates" ] || { echo "LiteLLMVirtualKey names used more than once: $duplicates" >&2; exit 2; }

failures=""
checked=0

# check <client> <key, or - for any served model> <file> <yq expression> [<prefix>]
# With a prefix, only models carrying it are LiteLLM's, and it is stripped.
check() {
  local client="$1" key="$2" file="$3" expr="$4" prefix="${5:-}" models allowed model
  models="$(tool yq -N "$expr" "$file")"
  if [ -z "$models" ] || grep -qx null <<< "$models"; then
    echo "$client: $file is missing a model at $expr" >&2
    exit 2
  fi
  [ -n "$key" ] || { echo "$client: its secretKeyRef matches no LiteLLMVirtualKey's Secret and key" >&2; exit 2; }
  allowed="$served"
  if [ "$key" != - ]; then
    allowed="$(tool yq -N "select(.kind == \"LiteLLMVirtualKey\" and .metadata.name == \"$key\") | .spec.models[]" "${keys[@]}")"
    [ -n "$allowed" ] || { echo "$client: no LiteLLMVirtualKey $key with models" >&2; exit 2; }
  fi
  while IFS= read -r model; do
    if [ -n "$prefix" ]; then
      [[ $model == "$prefix"* ]] || continue
      model="${model#"$prefix"}"
    fi
    checked=$((checked + 1))
    if ! grep -qxF -- "$model" <<< "$served"; then
      failures+="$client: $model is not served by LiteLLM"$'\n'
    elif ! grep -qxF -- "$model" <<< "$allowed"; then
      failures+="$client: $model is not in virtual key $key"$'\n'
    fi
  done <<< "$models"
}

for file in "${keys[@]}"; do
  for key in $(tool yq -N 'select(.kind == "LiteLLMVirtualKey") | .metadata.name' "$file"); do
    check "virtual key $key" - "$file" \
      "select(.kind == \"LiteLLMVirtualKey\" and .metadata.name == \"$key\") | .spec.models[]"
  done
done

# key_for <file> <yq path to a secretKeyRef>: the virtual key that mints the
# Secret and data key the reference names, reading "{{ .Release.Name }}" as the
# HelmRelease's name.
key_for() {
  local release name data
  release="$(tool yq -N '.metadata.name' "$1")"
  name="$(tool yq -N "$2.name" "$1")"
  name="${name//"{{ .Release.Name }}"/$release}"
  data="$(tool yq -N "$2.key" "$1")"
  tool yq -N "select(.kind == \"LiteLLMVirtualKey\" and .spec.secretName == \"$name\" and (.spec.secretKey // \"key\") == \"$data\") | .metadata.name" "${keys[@]}"
}

hermes=kubernetes/apps/ai/hermes/app/helmrelease.yaml
check hermes "$(key_for "$hermes" '.spec.values.controllers.hermes.containers.app.env.LITELLM_API_KEY.valueFrom.secretKeyRef')" \
  kubernetes/apps/ai/hermes/app/configmap.yaml \
  '.data["config.yaml"] | from_yaml | (.providers.litellm.default_model, .model.default)'

memini=kubernetes/apps/ai/memini/app/helmrelease.yaml
env=.spec.values.controllers.main.containers.main.env
check memini "$(key_for "$memini" "$env.MEMINI_LLM_API_KEY.valueFrom.secretKeyRef")" "$memini" \
  "$env | (.MEMINI_LLM_MODEL, .MEMINI_DISTILL_MODEL)"
check memini "$(key_for "$memini" "$env.MEMINI_RERANK_API_KEY.valueFrom.secretKeyRef")" "$memini" "$env.MEMINI_RERANK_MODEL"

kritika=kubernetes/apps/kritika/kritika/app/helmrelease.yaml
kritika_key="$(key_for "$kritika" '.spec.values.env.LITELLM_API_KEY.valueFrom.secretKeyRef')"
check kritika "$kritika_key" "$kritika" \
  '.spec.values.config | (.review.model, .review.fallback, .embedding.model)' litellm/
check "kritika pricing" "$kritika_key" "$kritika" \
  '.spec.values.config.providers.litellm.pricing | keys | .[]'

if [ -n "$failures" ]; then
  printf '%s' "$failures" | sort -u >&2
  exit 1
fi
echo "$checked model references resolve"
