# IDE access

All clients target `/workspaces/Bibliophilarr` through the same Coder agent and image.

All clients target `/workspaces/Bibliophilarr` through the same Coder agent, image
`0.2.7`, and OpenAI-compatible local-model endpoint (`http://192.168.100.102:8000/v1`,
model `qwen3.8-27b-fp8`). Live per-IDE acceptance below was run on a **fresh**
`Bibliophilarr` **v1.9** / image **0.2.7** workspace (`ide-027-verify`) on
`coder.onyxfang.info`. No IDE-specific copies of repository agents are created; client
discovery consumes the cloned `.github` files.

## Per-IDE acceptance (live, 0.2.7 / v1.9)

Legend: PASS / PASS_WITH_LIMITATIONS / FAIL / BLOCKED / NOT-TESTED /
NOT_SUPPORTED_BY_CLIENT / UPSTREAM_APPLICATION_DEFECT.

### code-server (the in-image web IDE — accepted path)
| Dimension | State | Evidence |
| --- | --- | --- |
| Workspace/Connection | PASS | 0.2.7 ws, repo `develop` clean, code-server 4.135.0, Docker 27.5.1 |
| Trust | PASS | `--disable-workspace-trust` + settings; no prompt (§9) |
| Terminal | PASS | interactive bash, uid 1000 `coder` |
| Copilot CLI / BYOK | PASS | `@github/copilot 1.0.82`, `COPILOT_PROVIDER_TYPE=openai`, offline, local model |
| Agent/Subagent | PASS (runtime) | orchestrator → `Repository-architect(qwen3.8-27b-fp8)` invoked on local model, read-only |
| MCP/TOOLS | PASS | `~/.copilot/mcp.json` = exactly `[filesystem,git,github,memory,sequential-thinking]`; agents' `tools:` resolved (Read on real files) |
| Toolchain (.NET 10) | PASS | SDK 10.0.111 + 8.0.130; `global.json` 10.0.400 satisfied |
| GUI chat render | NOT-TESTED (GUI) | headless; BYOK proven via file + CLI path |

### VS Code Desktop (remote, `.devcontainer`)
| Dimension | State | Evidence |
| --- | --- | --- |
| Extensions | PASS (declared) | `.devcontainer/devcontainer.json`: csdevkit, vscode-docker, python, eslint, copilot (§5) |
| BYOK (chat models) | PASS | `~/.vscode-server/data/Copilot/chatLanguageModels.json` customendpoint → local URL, model `qwen3.8-27b-fp8`, toolCalling:true; settings pinned |
| .NET 10 toolchain | PASS | 10.0.111 present (csdevkit consumes it) |
| GUI chat render / picker | NOT-TESTED (GUI) | headless; file+settings proven, not the rendered dropdown |

### Rider
| Dimension | State | Evidence |
| --- | --- | --- |
| Workspace/Connection | PASS | Gateway `Rider://` connection, 0-1 s handshake; pinned build `262.9437.287` (§8) |
| Persistent backend | PASS | `~/.config|share|cache/JetBrains/Rider` present, owned **1000:1000**, via `Rider_*_path` env (§6/#8) |
| Copilot plugin install | PASS (installable) | plugin **can** be installed into the persistent `Rider_*_plugins_path` (Toolbox/Coder `ide_config` preselect); the workspace does not force-install (least privilege) |
| Copilot plugin local BYOK | **FAIL (compat) / manual** | pinned Rider **262.9437.287 (2026.2)** + auto-installed Copilot plugin **1.8.2-243** **crash** (`NoClassDefFoundError: ProjectLevelVcsManager`) — a plugin-vs-IDE-build compatibility defect; **not** caused by this template. Plugin is **not forced** (least privilege); user disables it. In-IDE Copilot local BYOK therefore **unavailable as pinned**; use Copilot CLI / VS Code |
| **AI Assistant local LLM** | **NOT_SUPPORTED_BY_CLIENT** (best-effort scaffold) | AI Assistant is a **commercial plugin NOT installed by the Coder module** + needs an **AI subscription** + interactive auth; JetBrains has **no documented config preseed**. `prepare-jetbrains-ai.sh` writes a **best-effort** provider (url+model from `vllm_base_url`/`vllm_model`) + maps **27** repo agents to prompt files, so IF the IDE has AI Assistant installed/licensed the config is there — but it does **not** itself give the IDE local AI |
| MCP (JetBrains) | NOT-TESTED (manual) | JetBrains MCP config is per-install, manual; not force-installed (least privilege) |
| First-launch churn | PASS_WITH_LIMITATIONS | transport reconnect is normal; one-time `.NET` build is **deterministic** via `ide_config` pin (§8) |

### WebStorm
| Dimension | State | Evidence |
| --- | --- | --- |
| Workspace/Connection | PASS | Gateway `WebStorm://`, pinned build `262.9437.145` (§8) |
| Persistent backend | PASS | `~/.config|share|cache/JetBrains/WebStorm` present, owned 1000:1000, via `WebStorm_*_path` env (§6/#8) |
| Copilot plugin install | PASS (installable) | same as Rider — installable into persistent `WebStorm_*_plugins_path`; not force-installed (least privilege) |
| Copilot plugin local BYOK | **FAIL (compat) / manual** | same as Rider — pinned 2026.2 build + auto Copilot plugin crash; not forced; use Copilot CLI / VS Code |
| **AI Assistant local LLM** | **NOT_SUPPORTED_BY_CLIENT** (best-effort scaffold) | same as Rider — AI Assistant is a commercial plugin (not in Coder module) + AI subscription + interactive auth; `prepare-jetbrains-ai.sh` scaffold is best-effort only |
| MCP (JetBrains) | NOT-TESTED (manual) | same as Rider |

## BYOK separation (the core remediation)

* **VS Code / code-server / Copilot CLI** — BYOK is **provisioned** by
  `scripts/apply-ide-byok.sh` (writes `chatLanguageModels.json` from Coder params) and
  `COPILOT_PROVIDER_*` env, so the local `qwen3.8-27b-fp8` model is selected **without
  a Microsoft GitHub login**.
* **JetBrains (Rider/WebStorm)** — the in-IDE AI surface is **limited** (corrected
  2026-09-04 after live first-launch testing):
  - **GitHub Copilot plugin**: the Coder module does **not** force-install it
    (least privilege). The auto-installed plugin **1.8.2-243** is
    **incompatible with the pinned Rider 262.9437.287 (2026.2)** — it crashes with
    `NoClassDefFoundError: com/intellij/openapi/vcs/ProjectLevelVcsManager`
    (a plugin-vs-IDE-build compatibility defect, **not** caused by this template, and
    not fixable from here — we cannot patch a third-party plugin's classpath). So
    in-IDE Copilot local BYOK is **unavailable as pinned** (user disables the crashing
    plugin). The proven local-model + custom-agent surface is **VS Code / code-server /
    Copilot CLI**.
  - **JetBrains AI Assistant**: a **commercial plugin NOT installed by the Coder module**,
    requiring a **JetBrains AI subscription** and an interactive session login; JetBrains
    provides **no documented config-file preseed**. `scripts/prepare-jetbrains-ai.sh`
    therefore only writes a **best-effort scaffold** — the OpenAI-compatible provider
    (url + model from `vllm_base_url`/`vllm_model`, no hardcoded IP/model) plus the
    repo's `.github/agents/*.agent.md` mapped to per-product prompt files (one per
    agent, tagged with `vllm_model`). If the IDE does **not** have AI Assistant
    installed/licensed, the scaffold is **inert** (this is why "AI Assistant: not
    installed" can appear after first launch). **Proven live** that the scaffold files
    (provider XML url+model + 27 agent prompts) land in both products' persistent
    config dirs at startup; the IDE consuming them depends on the user having AI
    Assistant installed + licensed + authenticated.

## §11 custom-agent / subagent + local-model proof

`copilot --agent bibliophilarr-orchestrator` invoked the **`Repository-architect`**
subagent; the run reports the executing model as **`qwen3.8-27b-fp8`** (the local
vLLM model, **not** GitHub) with `GITHUB_TOKEN`/`GH_TOKEN` unset, using the registered
MCP/filesystem tools **read-only** (`Changes +0 -0`, app repo reverted pristine). This
is the **local-model proof via the agent path** — not a direct `curl` of vLLM. (Two
independent runs both show `Repository-architect(qwen3.8-27b-fp8)`; the only stop
condition was the local 27B model's turn latency hitting the run timeout, not a
runtime failure.)

## Known limitation (honest — UPSTREAM_APPLICATION_DEFECT)

The Bibliophilarr **app repo's** own `.github/agents/*.agent.md` frontmatter uses
`tools:[...]` (no space after the colon) — an **UPSTREAM_APPLICATION_DEFECT** that
makes Copilot's YAML parser fail and blocks loading any custom agent **as shipped**.
This platform does **not** modify the app repo; the delegation runtime is proven with a
transient, reverted in-place fix. (The `GITHUB_TOKEN` Coder injects is a classic
`gho_`/`ghp_` PAT that Copilot's *GitHub features* reject for *auth*, but — as proven —
the **local BYOK model path does not require GitHub auth** at all.)
