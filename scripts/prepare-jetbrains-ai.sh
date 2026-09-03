#!/usr/bin/env bash
# prepare-jetbrains-ai.sh — §2/#3 (JetBrains branch): best-effort AI Assistant scaffold.
#
# IMPORTANT (honest capability, corrected 2026-09-04 after live first-launch testing):
#   * JetBrains **AI Assistant** is a **commercial plugin that is NOT installed by the
#     Coder JetBrains module** and requires a **JetBrains AI subscription** to
#     authenticate. It is therefore **NOT a guaranteed in-box local-model vehicle**.
#   * JetBrains provides **no documented, stable config-file preseed** for AI Assistant
#     providers/custom prompts, and the session authentication is interactive.
#   => This script is a **best-effort scaffold only**: it writes the provider
#     (base URL + model from Coder params) + maps repo custom agents to prompt files so
#     that IF the user installs+licenses+authenticates AI Assistant, the config is
#     already in the persistent dir. By itself it does NOT make the IDE have local AI.
#   The PROVEN local-model + custom-agent paths are **VS Code / code-server / Copilot
#     CLI** (see apply-ide-byok.sh + register-copilot-mcp.sh + the Copilot CLI), which ARE
#     wired and proven to select qwen3.8-27b-fp8 without a Microsoft login.
#
# What this scaffold still does (deterministic, least-privilege, non-fatal):
#   * Writes the OpenAI-compatible provider (vllm_base_url / vllm_model) into the
#     persistent per-product config dirs — no hardcoded IP/model.
#   * Maps the repo's .github/agents/*.agent.md to per-product prompt files.
#   * NEVER modifies the app repo (agents are READ-only) and writes no secret unless
#     the operator supplies LOCAL_LLM_API_KEY.
#
# Idempotent + safe. Does not block startup (worst case: the IDE simply doesn't have
# AI Assistant installed/licensed, and the scaffold is inert).
set -euo pipefail
# media-common is a sourced runtime function library (not necessarily in the repo tree).
# shellcheck source=/dev/null
source /opt/workspace/bin/media-common 2>/dev/null || true

provider=${LOCAL_LLM_PROVIDER:-none}
if [[ ${provider} != vllm ]]; then
  echo "prepare-jetbrains-ai: provider=${provider} (not vllm); nothing to seed"
  exit 0
fi
base_url=${LOCAL_LLM_BASE_URL:-}
model=${LOCAL_LLM_MODEL:-}
api_key=${LOCAL_LLM_API_KEY:-}
# Strip a trailing /v1 from the base url only if the user supplied the full chat path —
# JetBrains expects the OpenAI-compatible root; keep whatever the operator gave as-is.
if [[ -z ${base_url} || -z ${model} ]]; then
  echo "prepare-jetbrains-ai: provider=vllm but base_url/model unset; skipping"
  exit 0
fi

home=${CODER_HOME:-/home/coder}
repo_dir=${BIBLIOPHILARR_REPOSITORY_DIR:-/workspaces/Bibliophilarr}
agents_dir="$repo_dir/.github/agents"
provider_id="bibliophilarr-local-vllm"

# The repo's agent files may not exist on a given ref; that is fine (best-effort).
agent_count=0

# ---- 1) Seed the AI Assistant "OpenAI-compatible" provider per product ------------
for product in Rider WebStorm; do
  cfg="$home/.config/JetBrains/$product"
  opts="$cfg/options"
  ai_dir="$cfg/ai.assistant"
  mkdir -p "$opts" "$ai_dir"

  # (a) Provider + model: a best-effort options file for the AI Assistant OpenAI
  #     provider (name/url/key/model). The exact schema is version-specific and NOT
  #     documented by JetBrains; this is the deterministic scaffold we verify live.
  cat > "$opts/aiAssistantOpenAiCompatibleProvider.xml" <<EOF
<application>
  <component name="LlmOpenAiCompatibleProviderSettings">
    <option name="name" value="${provider_id}" />
    <option name="baseUrl" value="${base_url}" />
    <option name="apiKey" value="${api_key}" />
    <option name="model" value="${model}" />
    <option name="enabled" value="true" />
  </component>
</application>
EOF

  # (b) Mark the provider the IDE should use for chat.
  cat > "$opts/aiAssistantProviderSelection.xml" <<EOF
<application>
  <component name="LlmProviderSelection">
    <option name="chatProviderId" value="${provider_id}" />
  </component>
</application>
EOF
  echo "prepare-jetbrains-ai: ${product} provider scaffold -> $opts (url+model from Coder params; key present=$([[ -n ${api_key} ]] && echo yes || echo no))"
done

# ---- 2) Map repo custom agents -> JetBrains custom prompts -----------------------
if [[ -d ${agents_dir} ]]; then
  for agent in "${agents_dir}"/*.agent.md; do
    [[ -f ${agent} ]] || continue
    # frontmatter `name:` and `description:` (single-line, as authored in the repo).
    a_name=$(awk -F': ' '/^name:/{print $2; exit}' "$agent" | tr -d '\r')
    a_desc=$(awk -F': ' '/^description:/{print $2; exit}' "$agent" | tr -d '\r')
    a_body=$(awk '/^---$/{c++; next} c==2{print}' "$agent")
    a_name=${a_name:-$(basename "$agent" .agent.md)}
    safe=$(printf '%s' "$a_name" | tr '/ ' '__')
    for product in Rider WebStorm; do
      ai_dir="$home/.config/JetBrains/$product/ai.assistant"
      mkdir -p "$ai_dir"
      {
        echo "name: ${a_name}"
        echo "description: ${a_desc:-}"
        echo "model: ${model}"
        echo "---"
        printf '%s\n' "$a_body"
      } > "$ai_dir/${safe}.prompt.md"
    done
    agent_count=$((agent_count+1))
  done
fi

# ---- ownership (backend runs as uid 1000) ----------------------------------------
if [[ "$(id -u)" -eq 1000 ]]; then
  chown -R 1000:1000 \
    "$home/.config/JetBrains/Rider/options" \
    "$home/.config/JetBrains/Rider/ai.assistant" \
    "$home/.config/JetBrains/WebStorm/options" \
    "$home/.config/JetBrains/WebStorm/ai.assistant" 2>/dev/null || true
fi

echo "prepare-jetbrains-ai: DONE (provider scaffold x2 products; ${agent_count} repo custom agents mapped to prompts)"
echo "prepare-jetbrains-ai: NOTE: this is a BEST-EFFORT scaffold only. JetBrains AI Assistant is a commercial"
echo "  plugin (NOT installed by the Coder module) needing an AI subscription + interactive auth; JetBrains"
echo "  ships no documented config preseed. If the IDE does not have AI Assistant installed/licensed, this"
echo "  scaffold is inert. The PROVEN local-model + custom-agent surface is VS Code / code-server / Copilot CLI."
