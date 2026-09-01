# IDE, AI, MCP, and GitHub integration

## IDE acceptance matrix

No live Coder or IDE was available; therefore nothing is marked PASS.

| Capability | VS Code | Rider | WebStorm | CLI |
|---|---|---|---|---|
| Open same workspace/repo visible | LIVE-TEST-REQUIRED | LIVE-TEST-REQUIRED | LIVE-TEST-REQUIRED | STATIC-PASS |
| Build/test/Git | LIVE-TEST-REQUIRED | LIVE-TEST-REQUIRED | LIVE-TEST-REQUIRED | LIVE-TEST-REQUIRED |
| GitHub operations | LIVE-TEST-REQUIRED | LIVE-TEST-REQUIRED | LIVE-TEST-REQUIRED | LIVE-TEST-REQUIRED |
| Repository agents/skills | LIVE-TEST-REQUIRED | LIVE-TEST-REQUIRED | LIVE-TEST-REQUIRED | LIVE-TEST-REQUIRED |
| MCP/local vLLM/tool calling | LIVE-TEST-REQUIRED | LIVE-TEST-REQUIRED | LIVE-TEST-REQUIRED | STATIC-PASS (test script only) |
| Subagent delegation | LIVE-TEST-REQUIRED | LIVE-TEST-REQUIRED | LIVE-TEST-REQUIRED | LIVE-TEST-REQUIRED |

Desktop VS Code connects with the Coder extension/`coder ssh`; browser code-server can be added only after validating the current registry module against the live server. Rider and WebStorm use the current Coder JetBrains Gateway procedure and the same `/workspaces/Bibliophilarr` folder. The image has server-side SDKs, but backend compatibility requires live tests.

## AI capability matrix

| Capability | VS Code Copilot | Copilot CLI | JetBrains Copilot | JetBrains AI Assistant |
|---|---|---|---|---|
| Local vLLM/OpenAI-compatible | LIVE-TEST-REQUIRED | LIVE-TEST-REQUIRED | NOT-TESTED | LIVE-TEST-REQUIRED |
| Repository custom agents | LIVE-TEST-REQUIRED | LIVE-TEST-REQUIRED | LIVE-TEST-REQUIRED | NOT-SUPPORTED as Copilot-agent equivalence |
| Subagents/MCP/tool calling | LIVE-TEST-REQUIRED | LIVE-TEST-REQUIRED | LIVE-TEST-REQUIRED | LIVE-TEST-REQUIRED; model support differs |

For Copilot CLI BYOK, a secret bootstrapper (not Terraform state) may map the vLLM secret to `COPILOT_PROVIDER_API_KEY` and set `COPILOT_PROVIDER_TYPE=openai`, `COPILOT_PROVIDER_BASE_URL`, and `COPILOT_MODEL`. Do not activate these until the installed CLI is checked against current official docs. `copilot_offline=true` also requires blocking GitHub, cloud MCP, telemetry, extensions, and updates before the workspace may be called offline. IDE keys belong in secure credential stores, never repository settings. JetBrains local-model support is not proof of Copilot-compatible orchestration.

## MCP profiles

| Profile | Installed | Enabled | Authorized |
|---|---|---|---|
| development | none until provider audit | filesystem, git, GitHub candidates | workspace write; GitHub per user scope |
| governance | none until provider audit | scoped filesystem/git/GitHub candidates | governance paths/metadata only |
| investigation | none until provider audit | read-only filesystem/git candidates | read/execute diagnostics |
| validator | none until provider audit | read-only files/git + controlled execute | candidate only; no GitHub write |

The actual Bibliophilarr MCP packages could not be discovered. Do not substitute similarly named packages. Pin and scan approved providers, measure enabled-tool count, startup failures, discovery latency, readiness, and any “Optimizing tools” stall.

## GitHub and agent discovery

Use Coder GitHub external auth or a least-scoped GitHub App; never embed a PAT, scrape credential helpers, or log OAuth material. Branch protection and human merge remain authoritative. After a live clone, inventory repository agent/skill/instruction paths and confirm each client discovers them. The required orchestrator→repository-architect smoke test was **BLOCKED** because the repository and runtime were inaccessible; it must be delegated, not answered manually.
