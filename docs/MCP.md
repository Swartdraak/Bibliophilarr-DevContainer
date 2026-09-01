# MCP runtime

No MCP package is baked in without an authoritative reference from Bibliophilarr `.github/agents` and
skills. GitHub access was blocked on 2026-09-01, so provider inventory and installation are **BLOCKED**.
The safe workaround is to restore repository access, extract referenced command/package/version fields,
pin those packages in `toolchain.json`, scan the resulting image, and rerun `verify-agent-runtime`.

Installation never implies enablement or authorization. Repository agent definitions choose their tools.
Workspace profiles restrict credentials and external policy; a global MCP catalog is forbidden. Live
acceptance records enabled tool count, startup failures, discovery latency, and agent readiness.
