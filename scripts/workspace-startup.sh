#!/usr/bin/env bash
set -euo pipefail
umask 077
repo_url=${BIBLIOPHILARR_REPOSITORY_URL:-https://github.com/Swartdraak/Bibliophilarr.git}
repo_dir=${BIBLIOPHILARR_REPOSITORY_DIR:-/workspaces/Bibliophilarr}
ref=${BIBLIOPHILARR_GIT_REF:-develop}; mode=${BIBLIOPHILARR_WORKSPACE_MODE:-development}
log=${WORKSPACE_STARTUP_LOG:-$HOME/.local/state/bibliophilarr/startup.log}
mkdir -p "$(dirname "$log")" "$(dirname "$repo_dir")"; exec > >(tee -a "$log") 2>&1
echo "workspace startup: mode=$mode requested_ref=$ref"
if [[ ! -d $repo_dir/.git ]]; then
  [[ ! -e $repo_dir || -z $(find "$repo_dir" -mindepth 1 -maxdepth 1 -print -quit) ]] || { echo "repository directory is non-empty" >&2; exit 10; }
  git clone --no-checkout "$repo_url" "$repo_dir"
fi
/opt/workspace/bin/checkout-ref.sh "$repo_dir" "$ref" "$mode"
initialize_test_media
if [[ ${MEDIA_MOUNT_MODE:-none} == read-only ]]; then verify-media; fi
if [[ ${LOCAL_LLM_PROVIDER:-none} == vllm ]]; then verify-local-llm --quick || echo "WARNING: local LLM check failed"; fi
/opt/workspace/bin/verify-workspace.sh "$repo_dir"
verify-agent-runtime "$repo_dir"
echo "workspace READY"
