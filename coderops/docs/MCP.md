# MCP

CoderOps provides a custom MCP server in `coderops/mcp/src/server.ts`.

## Tools

- `coderops_inventory`
- `coderops_capabilities`
- `coderops_health`
- `coderops_plan_change`
- `coderops_apply_change`
- `coderops_verify`

## Native Coder MCP

CoderOps does not replace Coder's native MCP. It detects it and prefers it when available.

## Adapter outputs

Generated adapter manifests are written to `coderops/adapters/generated`.