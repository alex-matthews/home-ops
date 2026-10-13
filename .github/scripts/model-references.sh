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

failures=""
checked=0

# check <client> <key, or - for the master key> <file> <yq expression>
check() {
  local client="$1" key="$2" file="$3" expr="$4" models allowed model
  models="$(tool yq -N "$expr" "$file")"
  if [ -z "$models" ] || grep -qx null <<< "$models"; then
    echo "$client: $file is missing a model at $expr" >&2
    exit 2
  fi
  allowed="$served"
  if [ "$key" != - ]; then
    allowed="$(tool yq -N "select(.kind == \"LiteLLMVirtualKey\" and .metadata.name == \"$key\") | .spec.models[]" "$litellm/litellmvirtualkeys.yaml")"
    [ -n "$allowed" ] || { echo "$client: no LiteLLMVirtualKey $key with models" >&2; exit 2; }
  fi
  while IFS= read -r model; do
    checked=$((checked + 1))
    if ! grep -qxF -- "$model" <<< "$served"; then
      failures+="$client: $model is not served by LiteLLM"$'\n'
    elif ! grep -qxF -- "$model" <<< "$allowed"; then
      failures+="$client: $model is not in virtual key $key"$'\n'
    fi
  done <<< "$models"
}

for key in $(tool yq -N 'select(.kind == "LiteLLMVirtualKey") | .metadata.name' "$litellm/litellmvirtualkeys.yaml"); do
  check "virtual key $key" - "$litellm/litellmvirtualkeys.yaml" \
    "select(.kind == \"LiteLLMVirtualKey\" and .metadata.name == \"$key\") | .spec.models[]"
done
check hermes - kubernetes/apps/ai/hermes/app/configmap.yaml \
  '.data["config.yaml"] | from_yaml | (.providers.litellm.default_model, .model.default)'
check memini memini kubernetes/apps/ai/memini/app/helmrelease.yaml \
  '.spec.values.controllers.main.containers.main.env | (.MEMINI_LLM_MODEL, .MEMINI_RERANK_MODEL)'
# kritika receives this key's value through its own ExternalSecret, so Git
# cannot show the link; the key's alias names it.
check kritika kritika kubernetes/apps/kritika/kritika/app/helmrelease.yaml \
  '.spec.values.config | (.reviewModel, .reviewFallback, .embeddingModel) | select(. != null and test("^litellm/")) | sub("^litellm/"; "")'
check "kritika pricing" kritika kubernetes/apps/kritika/kritika/app/helmrelease.yaml \
  '.spec.values.configFile.providers.litellm.pricing | keys | .[]'

if [ -n "$failures" ]; then
  printf '%s' "$failures" | sort -u >&2
  exit 1
fi
echo "$checked model references resolve"
