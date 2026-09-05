# CoderOps

CoderOps is the operational layer for the Bibliophilarr Coder workspace platform. It complements Coder's native interfaces with deterministic discovery, policy, drift detection, audit logging, and a custom MCP server.

## What lives here

- `coderops/mcp/` - TypeScript core, CLI, and MCP server
- `coderops/agents/` - canonical agent definitions
- `coderops/skills/` - canonical skill sources
- `coderops/instructions/` - canonical operational instructions
- `coderops/schemas/` - versioned JSON schemas
- `coderops/adapters/generated/` - generated client adapter artifacts
- `coderops/scripts/` - bootstrap, verification, and adapter generation helpers

## Quick start

```bash
cd coderops/mcp
npm install
npm run build
node dist/cli.js doctor --json
```

## Design

CoderOps separates generic operational logic from Bibliophilarr-specific integration. The implementation prefers native Coder interfaces when available, falls back to CLI/API inspection when necessary, and never mutates the Coder database directly.

## Runtime state

Runtime audit records and change plans are written outside the Git tree under an XDG-compatible state directory.