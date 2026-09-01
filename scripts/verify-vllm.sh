#!/usr/bin/env bash
set -euo pipefail
base=${VLLM_BASE_URL:?VLLM_BASE_URL is required}; model=${VLLM_MODEL:?VLLM_MODEL is required}; key=${VLLM_API_KEY:-}
auth=(); [[ -z $key ]] || auth=(-H "Authorization: Bearer $key")
curl_args=(-fsS --connect-timeout 5 --max-time 30 -H 'Content-Type: application/json' "${auth[@]}")
models=$(curl "${curl_args[@]}" "$base/models")
jq -e --arg m "$model" '.data[] | select(.id==$m)' <<<"$models" >/dev/null || { echo "configured model unavailable" >&2; exit 31; }
[[ ${1:-} == --quick ]] && { echo "vLLM models endpoint: PASS"; exit 0; }
payload=$(jq -nc --arg m "$model" '{model:$m,messages:[{role:"user",content:"Reply OK"}],max_tokens:8,stream:false}')
curl "${curl_args[@]}" -d "$payload" "$base/chat/completions" | jq -e '.choices[0].message.content' >/dev/null
stream=$(jq -nc --arg m "$model" '{model:$m,messages:[{role:"user",content:"Reply OK"}],max_tokens:8,stream:true}')
curl "${curl_args[@]}" -N -d "$stream" "$base/chat/completions" | rg -q '^data:'
tool=$(jq -nc --arg m "$model" '{model:$m,messages:[{role:"user",content:"What is the weather in Oslo? Use the tool."}],tools:[{type:"function",function:{name:"weather",description:"Get weather",parameters:{type:"object",properties:{city:{type:"string"}},required:["city"]}}}],tool_choice:"required",max_tokens:64}')
curl "${curl_args[@]}" -d "$tool" "$base/chat/completions" | jq -e '.choices[0].message.tool_calls[0].function.name=="weather"' >/dev/null
echo "vLLM completion, streaming, and tool calling: PASS (model=$model)"
