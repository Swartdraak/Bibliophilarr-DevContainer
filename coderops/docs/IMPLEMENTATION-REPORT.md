# Implementation Report

## Executive Summary

CoderOps now has a working TypeScript MCP/CLI foundation, canonical agent and skill sources, schema files, adapter-generation scripts, and documentation scaffolding.

## Repository Changes

- added `coderops/mcp` runtime package
- added canonical agent, skill, instruction, and schema sources under `coderops/`
- added generated adapter manifests and root adapter copies
- added bootstrap and verification scripts

## Architecture

The runtime keeps policy, discovery, drift, and audit separate from the MCP protocol layer.

## Native Coder MCP

Native Coder MCP is discovered but not reimplemented.

## CoderOps MCP

The custom MCP server exposes inventory, capability, health, change-plan, apply, and verify tools.

## Agents

Six canonical agents were added: governor, platform operator, template engineer, workspace operator, AI operator, and security auditor.

## Skills

Eleven canonical skills were added, plus a Bibliophilarr-specific diagnostics skill.

## Adapters

Generated adapters exist for Copilot-style MCP configuration, generic MCP profiles, `.github/agents`, `.github/skills`, and `.agents/skills`.

## Security

Modes, risk gates, redaction, and approval requirements are implemented in the core policy layer.

## Tests

- `npm run build` in `coderops/mcp` passed after the MCP server wiring was corrected.

## Live Validation

Live Coder validation has not been run yet in this workspace.

## Blockers

None for local build and generation; live Coder authentication and deployment validation still need environment confirmation.

## Known Limitations

Template/workspace/Coder API operations are mostly discovery-first and intentionally degrade to unknown when live Coder data is unavailable.

## Future Enhancements

- expand API-backed workspace/template lists
- add richer JSON schema validation to the CLI outputs
- wire live template publish and rollback operations behind approval IDs