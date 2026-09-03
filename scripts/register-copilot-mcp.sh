#!/usr/bin/env bash
# register-copilot-mcp.sh — §7 deterministic minimal MCP/tool registration for the
# Bibliophilarr custom agents (orchestrator / repository-architect).
#
# The agents' .agent.md `tools:` lists declare a fixed, least-privilege tool set:
#   vscode, read, search, agent, todo, filesystem/*, git/*, github/*,
#   memory/*, sequential-thinking/*
# `read`, `search`, `agent`, `todo`, `vscode` are BUILT-IN Copilot CLI tools (no
# MCP needed). The `*/`-namespaced entries are MCP servers that MUST be registered
# in ~/.copilot/mcp.json or the agents hang waiting for unavailable tools (the
# live "directory/search tool unavailable -> freezes" symptom).
#
# This registers EXACTLY the five servers the agents reference (least privilege;
# nothing extra is granted) so tool resolution is deterministic at agent launch.
# Idempotent: regenerates a single mcp.json each start.
set -euo pipefail
copilot_cfg="$HOME/.copilot"
mkdir -p "$copilot_cfg"
mcp_file="$copilot_cfg/mcp.json"
cat > "$mcp_file" <<'EOF'
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/workspaces/Bibliophilarr"]
    },
    "git": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-git", "--repository", "/workspaces/Bibliophilarr"]
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"]
    },
    "memory": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"]
    },
    "sequential-thinking": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
    }
  }
}
EOF
# github MCP reads GITHUB_TOKEN/GH_TOKEN at invocation (env already in agent).
chown -R "$(id -u):$(id -g)" "$copilot_cfg" 2>/dev/null || true
echo "register-copilot-mcp: registered $(( $(grep -c '\"command\"' "$mcp_file") )) MCP servers to $mcp_file (least-privilege set for orchestrator + repository-architect)"
