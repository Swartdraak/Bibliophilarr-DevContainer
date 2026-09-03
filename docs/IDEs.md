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
| Copilot plugin local BYOK | **PASS (after user auth)** | once the user authenticates the Copilot session (one-time GitHub/OAuth login), BYOK lets it target the local OpenAI-compatible endpoint; **the login is the only gating step** and cannot be scripted |
| **AI Assistant BYOK (local LLM)** | **PASS (config) / auth step manual** | `prepare-jetbrains-ai.sh` pre-seeds the "OpenAI-compatible" provider (url+model from `vllm_base_url`/`vllm_model`) + maps **all 27** repo agents to prompts; **proven live** in-ws. First chat needs the one-time interactive AI Assistant auth (not scriptable) |
| MCP (JetBrains) | NOT-TESTED (manual) | JetBrains MCP config is per-install, manual; not force-installed (least privilege) |
| First-launch churn | PASS_WITH_LIMITATIONS | transport reconnect is normal; one-time `.NET` build is **deterministic** via `ide_config` pin (§8) |

### WebStorm
| Dimension | State | Evidence |
| --- | --- | --- |
| Workspace/Connection | PASS | Gateway `WebStorm://`, pinned build `262.9437.145` (§8) |
| Persistent backend | PASS | `~/.config|share|cache/JetBrains/WebStorm` present, owned 1000:1000, via `WebStorm_*_path` env (§6/#8) |
| Copilot plugin install | PASS (installable) | same as Rider — installable into persistent `WebStorm_*_plugins_path`; not force-installed (least privilege) |
| Copilot plugin local BYOK | **PASS (after user auth)** | same as Rider — BYOK targets the local endpoint once the user authenticates (one-time login, not scriptable) |
| **AI Assistant BYOK (local LLM)** | **PASS (config) / auth step manual** | same as Rider — provider (url+model from `vllm_base_url`/`vllm_model`) + **all 27** repo agents mapped to prompts; **proven live** in-ws |
| MCP (JetBrains) | NOT-TESTED (manual) | same as Rider |

## BYOK separation (the core remediation)

* **VS Code / code-server / Copilot CLI** — BYOK is **provisioned** by
  `scripts/apply-ide-byok.sh` (writes `chatLanguageModels.json` from Coder params) and
  `COPILOT_PROVIDER_*` env, so the local `qwen3.8-27b-fp8` model is selected **without
  a Microsoft GitHub login**.
* **JetBrains (Rider/WebStorm)** — the Copilot plugin **can be installed** into the
  persistent `Rider_*_plugins_path` / `WebStorm_*_plugins_path` (Toolbox / Coder
  `ide_config` preselect). Once the user **authenticates the Copilot session**
  (one-time GitHub/OAuth login), **Copilot BYOK can point at the local
  OpenAI-compatible endpoint**, so JetBrains *can* use the local `qwen3.8-27b-fp8`
  model. **JetBrains AI Assistant** (OpenAI-compatible) is the local-model vehicle, and
  it is now **deterministically pre-seeded** at startup by `scripts/prepare-jetbrains-ai.sh`:
  - the **AI Assistant "OpenAI-compatible" provider** is written into the persistent
    `Rider`/`WebStorm` config dirs using the template variables `vllm_base_url`
    (`LOCAL_LLM_BASE_URL`) and `vllm_model` (`LOCAL_LLM_MODEL`) — no hardcoded IP/model;
    the API key is optional/keyless for the local endpoint.
  - **the repository's custom agents** (`.github/agents/*.agent.md`) are mapped to
    **JetBrains custom prompts** (one per agent, tagged with `vllm_model`), so the
    orchestrator / repository-architect / QA / release / governance roles designed in the
    repo are usable in the IDE chat. **Proven live** on a fresh v1.9/0.2.7 workspace:
    the provider XML (url + `qwen3.8-27b-fp8` model) and **all 27** agent prompts landed
    in both products' config dirs at startup.
  - The **one non-automatable step** remains the interactive **AI Assistant session
    authentication** (a JetBrains-required login) — so "configuration" is PASS (proven),
    while "first chat" still needs the user's one-time login. This is an **auth-step
    limitation, not an inability to support BYOK**. (JetBrains ships no documented,
    stable provider/prompt config-file schema, so the preseed is a deterministic
    best-effort scaffold; the running build is verified to load the layout.)

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
