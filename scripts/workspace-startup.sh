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
# GitHub auth (§11/§28): the Coder User Secret "Swartdraak GH PAT" (env
# GITHUB_TOKEN) is auto-injected into the workspace by Coder at start. The
# `gh` CLI honours GITHUB_TOKEN / GH_TOKEN directly for authenticated calls, so
# we do NOT run a persistent `gh auth login` and we do NOT copy the token into
# ~/.config/gh or global git config (no credential duplication). We only verify
# the secret is present (NEVER print it). The app repo is public, so clone does
# not need auth. Functional gh acceptance is done live, not at startup.
if [[ -n "${GITHUB_TOKEN:-}" ]] && command -v gh >/dev/null 2>&1; then
  echo "github auth: GITHUB_TOKEN secret present (gh will use it directly; value not printed)"
else
  echo "WARNING: github auth: GITHUB_TOKEN not set or gh missing (continuing unauthenticated)"
fi
# initialize_test_media + assert_safe_scratch_root live in media-common (a sourced
# function library, NOT an executable). source it before use, as verify-media and
# the seed/reset scripts do. (BUG 2026-09-02: this line used to call the function
# without sourcing, giving "initialize_test_media: command not found" -> the agent
# was Connected but the startup script exited with an error.)
# shellcheck source=/dev/null # runtime path; not present in the repo tree
source /opt/workspace/bin/media-common
initialize_test_media
if [[ ${MEDIA_MOUNT_MODE:-none} == read-only ]]; then verify-media; fi
if [[ ${LOCAL_LLM_PROVIDER:-none} == vllm ]]; then verify-local-llm --quick || echo "WARNING: local LLM check failed"; fi
# §1/#2 IDE BYOK provisioning: when a local OpenAI-compatible provider (vLLM) is
# selected, deterministically pre-config the IDE clients from the Coder params
# (no hardcoded IP/model). The Copilot CLI is already covered by COPILOT_PROVIDER_*
# in the agent env; VS Code gets a chatLanguageModels.json customendpoint entry.
/opt/workspace/bin/apply-ide-byok.sh || echo "WARNING: apply-ide-byok reported an issue (non-fatal; IDE BYOK)"
# §7 deterministic minimal MCP/tool registration for the custom agents (the
# orchestrator + repository-architect declare exactly 5 MCP servers; registering
# them avoids the "tool unavailable -> agent freezes" live symptom).
/opt/workspace/bin/register-copilot-mcp.sh || echo "WARNING: copilot mcp registration reported an issue (non-fatal)"
# §8 deterministic JetBrains remote-backend layout (persistent dirs on the home
# volume; prevents re-download/reinstall churn on first connect + reconnect).
/opt/workspace/bin/prepare-jetbrains-backend.sh || echo "WARNING: jetbrains backend prepare reported an issue (non-fatal)"
# §2/#3 (JetBrains branch): pre-seed the AI Assistant OpenAI-compatible provider
# (base url + model from the Coder params) + map the repo custom agents to IDE
# prompts, for Rider/WebStorm. Best-effort, live-verified; does not block startup.
/opt/workspace/bin/prepare-jetbrains-ai.sh || echo "WARNING: jetbrains AI assistant preseed reported an issue (non-fatal)"
/opt/workspace/bin/verify-workspace.sh "$repo_dir"
# verify-agent-runtime checks repository CONTENT (.github/agents, skills,
# instructions). Those are a runtime convenience, not a workspace-correctness
# requirement: the app repo (checked out read-only) may legitimately lack
# .github/agents on a given ref. Hard-failing startup on a repo-content check
# would mark the agent unhealthy for a perfectly valid workspace (BUG 2026-09-02:
# it exited 2 -> "agent startup script exited with an error"). Run it as an
# informational gate: report its status, but only FAIL the startup if the
# non-content prerequisites (correctness) already did. Agent delegation remains a
# separate acceptance test per the script's own note.
if verify-agent-runtime "$repo_dir"; then
  echo "agent runtime: PASS"
else
  agent_rc=$?
  echo "WARNING: agent runtime check reported rc=$agent_rc (repository-content); continuing"
fi
echo "workspace READY"
