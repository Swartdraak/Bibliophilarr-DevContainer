# Architecture

CoderOps has three layers:

1. Canonical policy and knowledge under `coderops/agents`, `coderops/skills`, `coderops/instructions`, and `coderops/schemas`.
2. The TypeScript runtime in `coderops/mcp`, which implements the CLI, audit log, policy checks, drift logic, and MCP server.
3. Generated adapters in `coderops/adapters/generated`, `.github/agents`, `.github/skills`, and `.agents/skills`.

The runtime prefers native Coder discovery first and uses CLI/API inspection for aggregated diagnostics and drift detection.