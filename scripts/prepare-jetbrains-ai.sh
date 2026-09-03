#!/usr/bin/env bash
# prepare-jetbrains-ai.sh — §2/#3 (JetBrains branch): pre-seed JetBrains AI Assistant.
#
# Goal (task): configure the JetBrains AI chat capability to use the LLM provided by
# the template variables (vllm_base_url / vllm_model) AND make the repo's custom agents
# (Swartdraak/Bibliophilarr .github/agents/*.agent.md) available, in Rider/WebStorm.
#
# Mechanism (documented, deterministic):
#   * The JetBrains AI Assistant is the app's local-model vehicle, and it supports an
#     "OpenAI-compatible" provider (Settings | AI Assistant | Providers & API keys).
#     We write that provider config (base URL + model) into the PERSISTENT per-product
#     config dir so the IDE loads it on first launch — no hardcoded IP/model. Values
#     come from the Coder parameters (LOCAL_LLM_BASE_URL / LOCAL_LLM_MODEL).
#   * The API key is OPTIONAL/keyless for the local vLLM endpoint. If a key is supplied
#     via LOCAL_LLM_API_KEY, it is written to config (not the app key-store binary); the
#     user may also complete the one-time provider authentication in the GUI.
#   * The repo's custom agents are mapped to JetBrains "custom prompts" so the same
#     orchestrator/architect roles designed in the repo are usable in the IDE chat.
#
# Honest limitation (kept explicit, NOT faked): JetBrains has NO documented, stable
# config-file format for AI Assistant providers/custom prompts, and the app still
# requires the interactive session authentication that cannot be scripted. So this
# pre-seed is the DETERMINISTIC BEST-EFFORT scaffold; whether the running build accepts
# it is verified live and classified accordingly. It NEVER modifies the app repo (the
# agents are only READ) and does not write a secret unless the operator provides one.
#
# Idempotent + safe. Does not block startup (worst case: IDE ignores the scaffold and
# the user completes the provider in the GUI).
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
echo "prepare-jetbrains-ai: NOTE: interactive AI Assistant session auth remains a manual GUI step (not scriptable); scaffold is best-effort and verified live."
