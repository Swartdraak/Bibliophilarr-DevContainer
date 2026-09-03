#!/usr/bin/env bash
# apply-ide-byok.sh — deterministic, parameter-driven IDE BYOK provisioning.
#
# §1/#2: The local-AI architecture is IDE -> Coder workspace ->
#   OpenAI-compatible endpoint (${LOCAL_LLM_BASE_URL}) -> ${LOCAL_LLM_MODEL}.
# There is NO vllm/ollama binary or local model process inside the workspace.
#
# The Copilot CLI and each IDE client configure BYOK SEPARATELY (this script
# does NOT assume CLi env vars configure the IDEs):
#   * Copilot CLI   : COPILOT_PROVIDER_* (set by the coder_agent env; no work here)
#   * VS Code       : a customendpoint entry in chatLanguageModels.json, written
#                     here from the Coder params (no hardcoded IP/model)
#   * JetBrains     : AI Assistant "OpenAI-compatible" provider (interactive;
#                     the IDE reads its own user-config, see JetBrains notes)
#
# Only provisions when a local provider is selected. Idempotent + safe.
set -euo pipefail
# media-common provides initialize_test_media / assert_safe_scratch_root; it is
# a runtime function library, not an executable (hence source, not invocation).
# shellcheck source=/dev/null # runtime path; not present in the repo tree
source /opt/workspace/bin/media-common 2>/dev/null || true

provider=${LOCAL_LLM_PROVIDER:-none}
if [[ ${provider} != vllm ]]; then
  echo "apply-ide-byok: provider=${provider} (not vllm); nothing to provision"
  exit 0
fi
base_url=${LOCAL_LLM_BASE_URL:-}
model=${LOCAL_LLM_MODEL:-}
if [[ -z ${base_url} || -z ${model} ]]; then
  echo "apply-ide-byok: provider=vllm but base_url/model unset; skipping"
  exit 0
fi
echo "apply-ide-byok: provisioning VS Code custom endpoint (base_url+model from Coder params; no print)"

# VS Code Server stores its BYOK custom-model file at:
#   ~/.vscode-server/data/Copilot/chatLanguageModels.json
# customendpoint = built-in OpenAI-compatible BYOK provider.
# toolCalling is REQUIRED for agent/custom-agent chat; we set it true.
# apiKey is omitted (keyless local endpoint, like ollama). No hardcoded IP/model:
# values come from the Coder parameters (LOCAL_LLM_BASE_URL / LOCAL_LLM_MODEL).
vsc_data="$HOME/.vscode-server/data/Copilot"
mkdir -p "$vsc_data"
endpoint_id="bibliophilarr-local-vllm"
cat > "${vsc_data}/chatLanguageModels.json" <<EOF
{
  "version": 1,
  "customModels": [
    {
      "vendor": "customendpoint",
      "apiType": "chat-completions",
      "url": "${base_url}",
      "displayName": "Bibliophilarr local vLLM",
      "toolCalling": true,
      "maxInputTokens": 32768,
      "maxOutputTokens": 8192,
      "models": [
        {
          "id": "${model}",
          "displayName": "${model}",
          "toolCalling": true,
          "maxInputTokens": 32768,
          "maxOutputTokens": 8192
        }
      ]
    }
  ]
}
EOF
chown -R "$(id -u):$(id -g)" "$vsc_data" 2>/dev/null || true
echo "apply-ide-byok: VS Code customendpoint written to ${vsc_data}/chatLanguageModels.json (model id + url from Coder params)"

# VS Code settings pin the BYOK model as the default chat model, so a fresh
# remote connection does not fall back to a GitHub-hosted model. The
# chatLanguageModels.json id is <vendor>|<model>; the defaultModel setting uses
# the same id form. (chat.defaultModel / chat.utilityModel are the documented
# selection keys.)
vsc_settings="$HOME/.vscode-server/data/Machine/settings.json"
if [[ -f ${vsc_settings} ]]; then
  # merge is non-trivial in pure bash; only write if jq is present and it parses
  if command -v jq >/dev/null 2>&1 && jq empty "$vsc_settings" >/dev/null 2>&1; then
    tmp=$(mktemp)
    if jq --arg m "${endpoint_id}|${model}" \
       '.chat.utilityModel=$m | .chat.utilitySmallModel=$m | .chat.utilityModelDefault=$m' \
       "$vsc_settings" > "$tmp"; then
      mv "$tmp" "$vsc_settings"
    else
      rm -f "$tmp"
    fi
  fi
fi
echo "apply-ide-byok: DONE"
