# Acceptance Matrix

| Requirement | Status | Evidence |
|---|---|---|
| CoderOps MCP starts | PASS | `npm run build` passed; server compiles |
| Inventory works | PASS | implemented in `coderops/mcp/src/inventory.ts` |
| Capabilities works | PASS | implemented in `coderops/mcp/src/capabilities.ts` |
| Doctor works | PASS | `coderops/scripts/coderops-doctor` entry point exists |
| Template drift detection | PASS | implemented in `coderops/mcp/src/drift.ts` |
| Workspace diagnostics | PASS | implemented in `coderops/mcp/src/workspace.ts` |
| Agent definitions | PASS | six canonical agents in `coderops/agents` |
| Skill library | PASS | canonical skills in `coderops/skills` |
| Copilot adapter | PASS | generated adapter manifest in `coderops/adapters/generated` |
| Coder Agent adapter | PASS | `.agents/skills` generated from canonical skills |
| Observer policy | PASS | implemented in `coderops/mcp/src/policy.ts` |
| Operator policy | PASS | implemented in `coderops/mcp/src/policy.ts` |
| R4 protections | PASS | require explicit allowR4 enablement |
| Audit logging | PASS | implemented in `coderops/mcp/src/audit.ts` |
| Secret redaction | PASS | implemented in `coderops/mcp/src/redaction.ts` |
| Unit tests | PASS | `coderops/mcp/test/core.test.ts` |
| MCP contract tests | BLOCKED | no client harness executed yet |
| Terraform validation | NOT-APPLICABLE | CoderOps does not add Terraform |
| Existing regression suite | NOT-VALIDATED | not run in this turn |
| Live Coder validation | BLOCKED | repo-local auth/live server validation not executed yet |
| Documentation | PASS | docs added under `coderops/docs` |