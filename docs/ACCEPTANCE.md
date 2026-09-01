# Acceptance matrix

Evidence date: 2026-09-01.

| Capability | Result | Evidence/blocker |
|---|---|---|
| Branch/exact SHA/dirty-worktree checkout | PASS | local bare-origin test |
| Scratch copy/reset/source preservation/traversal rejection | PASS | isolated local test |
| Coder publish/provision | BLOCKED | proxy rejects Coder URL with HTTP 403 |
| Bibliophilarr clone/agents | BLOCKED | proxy rejects GitHub with HTTP 403 |
| Image/Docker | BLOCKED | Docker unavailable |
| vLLM completion/stream/tool call | NOT-TESTED | endpoint/model unavailable |
| Orchestrator delegation/MCP | BLOCKED | repository, workspace, model unavailable |
| Real media read-only | BLOCKED | provisioner host inaccessible |
| VS Code/Rider/WebStorm | NOT-TESTED | workspace unavailable |
| Repeatability/destroy/recreate/rollback | BLOCKED | Coder API unreachable |

No blocked or untested item is represented as a pass.
