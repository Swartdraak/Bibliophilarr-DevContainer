#!/usr/bin/env bash
set -euo pipefail
repo=${1:-${BIBLIOPHILARR_REPOSITORY_DIR:-/workspaces/Bibliophilarr}}
version() { local name=$1; shift; printf '%-18s ' "$name"; "$@" 2>/dev/null | head -n1 || echo NOT-AVAILABLE; }
version OS sh -c '. /etc/os-release; echo "$PRETTY_NAME"'
version Architecture uname -m; version .NET dotnet --version; version Node node --version
version Yarn yarn --version; version Git git --version; version GitHub gh --version
version Copilot copilot --version; version Docker docker --version; version Compose docker compose version
printf '%-18s %s\n' 'Workspace image' "${WORKSPACE_IMAGE_VERSION:-UNKNOWN}"
printf '%-18s %s\n' 'Repository' "$repo"
if [[ -d $repo/.git ]]; then
  printf '%-18s %s\n' Ref "$(git -C "$repo" symbolic-ref --short -q HEAD || echo detached)"
  printf '%-18s %s\n' HEAD "$(git -C "$repo" rev-parse HEAD)"
fi
printf '%-18s %s\n' 'Docker daemon' "$(docker info >/dev/null 2>&1 && echo AVAILABLE || echo UNAVAILABLE)"
printf '%-18s %s\n' 'Local LLM' "$( [[ ${LOCAL_LLM_PROVIDER:-none} == vllm ]] && verify-local-llm --quick >/dev/null 2>&1 && echo REACHABLE || echo NOT-CONFIGURED-OR-UNREACHABLE)"
printf '%-18s %s\n' 'Agents' "$(find "$repo/.github/agents" -maxdepth 1 -type f -name '*.agent.md' 2>/dev/null | wc -l)"
printf '%-18s %s\n' 'Scratch media' "$([[ -d /workspace-test-media && -w /workspace-test-media ]] && echo WRITABLE || echo UNAVAILABLE)"
