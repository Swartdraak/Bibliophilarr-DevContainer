#!/usr/bin/env bash
# two-workspace-evidence.sh — collect per-workspace acceptance evidence for the
# §13 two-workspace test. Run it by piping the remote command into `coder ssh <ws> --`.
#
# Usage (from outside):
#   coder ssh WS-NAME -- scripts/two-workspace-evidence.sh   # (file present in the workspace)
#
# Emits a stable key=value block so two workspaces can be diffed mechanically for
# uniqueness (container ids, dinD id, home/scratch/socket volume names).
#
# Read-only + harmless writes to the workspace scratch dir only (/workspace-test-media).

set -uo pipefail

echo "## ws-evidence"
echo "uid_user=$(id -un) uid_num=$(id -u)"

# Repo path + HEAD + clean
repo="$(pwd)"
if [ -d "$repo/.git" ]; then
  echo "repo_path=$repo"
  echo "repo_branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  echo "repo_head=$(git -C "$repo" rev-parse HEAD 2>/dev/null)"
  echo "repo_dirty_count=$(git -C "$repo" status --porcelain 2>/dev/null | wc -l)"
fi

# code-server app (the workspace dev server)
if command -v code-server >/dev/null 2>&1; then
  echo "codeserver_bin=$(command -v code-server)"
  echo "codeserver_version=$(code-server --version 2>/dev/null | head -1)"
fi

# JetBrains / IDE metadata (the image ships code-server as the IDE web path; a
# JetBrains in-box IDE is not part of the 0.2.6 image, so capture what is present).
echo "jb_dir=$([ -d /opt/jetbrains ] && find /opt/jetbrains -maxdepth 1 -mindepth 1 2>/dev/null | tr '\n' ',' || echo 'absent')"
[ -f /workspace/ide-metadata.json ] && echo "ide_metadata=$(tr -d '\n' < /workspace/ide-metadata.json 2>/dev/null)"

# vLLM local LLM reachability (from the workspace)
vllm_url="${LOCAL_LLM_BASE_URL:-${VLLM_BASE_URL:-http://192.168.100.102:8000/v1}}"
if curl -fsS --max-time 8 "$vllm_url/models" >/dev/null 2>&1; then
  echo "vllm_reachable=true vllm_url=$vllm_url"
else
  echo "vllm_reachable=false vllm_url=$vllm_url"
fi

# DinD (nested) capability + dock socket path
export DOCKER_HOST=unix:///var/run/docker/docker.sock
echo "docker_host=$DOCKER_HOST"
echo "docksocket=$([ -S /var/run/docker/docker.sock ] && echo present || echo absent) path=/var/run/docker/docker.sock"
echo "nested_docker_server=$(timeout 25 docker version --format '{{.Server.Version}}' 2>/dev/null)"
echo "nested_compose=$(docker compose version 2>/dev/null | head -1)"

# Media read-only: write must be REJECTED, read must work
if touch /media/audiobooks/__evidence_ro_probe.txt 2>/dev/null; then
  rm -f /media/audiobooks/__evidence_ro_probe.txt
  echo "media_write_allowed=UNEXPECTED (should be ro)"
else
  echo "media_write_rejected=true"
fi
if ls /media/audiobooks >/dev/null 2>&1; then
  echo "media_read_allowed=true"
else
  echo "media_read_allowed=false"
fi

# Scratch bidirectional via bind-mount of the shared scratch path
if [ -d /workspace-test-media ]; then
  probe_marker="ws-evidence-$(date +%s)-$$"
  echo "$probe_marker" > /workspace-test-media/scratch_probe.txt
  nested_out="$(timeout 60 docker run --rm -v /workspace-test-media:/scratch alpine:3.19 sh -c "cat /scratch/scratch_probe.txt" 2>/dev/null)"
  echo "scratch_ws_to_nested=$([ "$nested_out" = "$probe_marker" ] && echo ok || echo fail)"
  timeout 60 docker run --rm -v /workspace-test-media:/scratch alpine:3.19 sh -c "echo nested-wrote > /scratch/scratch_nested.txt" 2>/dev/null
  echo "scratch_nested_to_ws=$([ "$(cat /workspace-test-media/scratch_nested.txt 2>/dev/null)" = "nested-wrote" ] && echo ok || echo fail)"
  rm -f /workspace-test-media/scratch_probe.txt /workspace-test-media/scratch_nested.txt
fi

echo "## ws-evidence-end"
