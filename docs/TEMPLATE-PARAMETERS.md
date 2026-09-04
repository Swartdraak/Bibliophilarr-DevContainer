# Template parameters — `Bibliophilarr` (workspace image 0.2.x)

Complete reference for every operator-facing parameter of the `Bibliophilarr`
Coder template (`template/main.tf`, `template/variables.tf`,
`template/versions.tf`), what each is used for, its default, whether it can be
changed after the workspace is created (`mutable`), and how it is consumed at
runtime.

Two distinct kinds of input exist:

1. **Coder parameters** (`data "coder_parameter"`) — shown in the Coder UI at
   workspace create/start; these are the knobs an operator actually turns.
2. **Terraform variables** (`variable` in `variables.tf`) — provisioner-level
   sizing + the repository URL. They are not surfaced as Coder parameters and
   are fixed per template version.

---

## Coder parameters (operator knobs)

Listed in `order` (the order they appear in the Coder UI).

### 0. `workspace_image`
- **Type:** string | **Default:** `ghcr.io/swartdraak/bibliophilarr-agent-workspace:0.2.7` | **mutable:** yes | **order:** 0
- **What it does:** the exact, **immutable** Docker image the workspace container
  is created from. This is a first-class Coder parameter (not just a Terraform
  default) so that on each template push its default refreshes to match the
  active template version — the template, the requested image, the running
  container, the `WORKSPACE_IMAGE_VERSION` env label, and `toolchain.json` all
  identify the **same artifact** (the deterministic image-identity fix).
- **Constraint:** validated to be a pinned tag or digest; `latest` is rejected
  (`"Pin an immutable version or digest, never latest."`).
- **Notes / usage:**
  - `0.2.7` = the baseline clean image (safe default).
  - `0.2.8` = adds the headless `assign-task` helper + the Rider NuGet ownership
    startup fix.
  - `0.2.9` = adds the `assign-task` loop-guard (`--max-turns`), recommended for
    headless agent runs on the local model.
  - Select a newer image for a workspace with
    `coder create <ws> --parameter workspace_image=ghcr.io/swartdraak/bibliophilarr-agent-workspace:0.2.9`
    (or the equivalent UI field). `main.tf` default stays at `0.2.7` as the safe
    rollback baseline.
- **Consumed by:** the `docker_container.workspace` `image` field.

### 1. `bibliophilarr_ref`
- **Type:** string | **Default:** `develop` | **mutable:** yes | **order:** 1
- **What it does:** the Git **branch, tag, or full 40-char SHA** to check out in
  `/workspaces/Bibliophilarr`. **It never falls back** — if the ref does not
  exist the checkout fails outright (exit 23), rather than silently checking out
  something else.
- **Notes / usage:**
  - Development: `develop` (default).
  - Validation: pass a **full 40-character SHA** so the validator pins an exact
    commit (checked out in detached HEAD).
  - A branch is checked out as a local tracking branch; a tag is checked out
    detached; a SHA is checked out detached and verified byte-for-byte.
- **Consumed by:** `BIBLIOPHILARR_GIT_REF` env → `scripts/checkout-ref.sh` at
  startup; also exposed as the Terraform output `requested_ref`.

### 2. `workspace_mode`
- **Type:** string (option list) | **Default:** `development` | **mutable:** **no**
  (fixed at create; stop/start keeps it) | **order:** 2
- **Options:** `development`, `ci-repair`, `governance`, `investigation`,
  `validator`, `staging-validation`, `release-validation`.
- **What it does:** selects the workspace's **intended role**. The single
  machine-observable effect is in `scripts/checkout-ref.sh`: if the existing
  worktree is **dirty** (has real uncommitted work):
  - `validator` or `release-validation` → **fails startup** ("validator
    repository is unexpectedly dirty", exit 20) — a validator must run from a
    clean tree.
  - any other mode → **skips the checkout** and protects the uncommitted work
    (exit 0).
  - A **fresh/unpopulated** clone (index empty) is always populated by checking
    out the requested ref regardless of mode.
- **Guidance** (from `docs/CODER.md`):
  - Development: `workspace_mode=development`, `bibliophilarr_ref=develop`, open
    via VS Code / SSH / Rider / WebStorm.
  - Validation: full SHA + `validator`.
  - Staging QA: `staging-validation` + read-only media.
  - **Each validator must use a separately named workspace.**
- **Consumed by:** `BIBLIOPHILARR_WORKSPACE_MODE` env → `checkout-ref.sh`; also
  exposed as agent metadata `mode` and Terraform output `workspace_mode`.

### 3. `inference_provider`
- **Type:** string (option list) | **Default:** `none` | **mutable:** yes | **order:** 3
- **Options:** `none`, `vllm` (OpenAI-compatible vLLM).
- **What it does:** selects the **local-model inference backend**. When set to
  `vllm`, the `vllm_*` parameters are mapped into the `COPILOT_PROVIDER_*` env
  (Copilot CLI custom-model-provider) and `LOCAL_LLM_*` env, and the startup
  script provisions the IDEs for **local BYOK** (no Microsoft/GitHub login for
  the local-model path):
  - `COPILOT_PROVIDER_BASE_URL`/`TYPE`/`MODEL`, `COPILOT_OFFLINE`
  - `LOCAL_LLM_PROVIDER`/`BASE_URL`/`MODEL`/`CONTEXT_LENGTH`
  - runs `apply-ide-byok.sh` (VS Code `chatLanguageModels.json` customendpoint
    + pins the utility model), `register-copilot-mcp.sh` (the 5 MCP servers the
    custom agents declare), and `prepare-jetbrains-ai.sh` (best-effort AI
    Assistant provider preseed + repo agents as IDE prompts).
- **Usage:** set `vllm` + fill the `vllm_*` fields to get the local
  `qwen3.8-27b-fp8` model across VS Code / code-server / Copilot CLI / Rider-CLI.
  Leave `none` for a plain (no local model) workspace.
- **Consumed by:** agent `env` (`COPILOT_PROVIDER_*`, `LOCAL_LLM_*`); gates
  `apply-ide-byok.sh`, `register-copilot-mcp.sh`, `prepare-jetbrains-ai.sh`, and
  `verify-local-llm --quick` in `workspace-startup.sh`.

### 4. `vllm_base_url`
- **Type:** string | **Default:** `""` | **mutable:** yes | **order:** 4
- **What it does:** the **OpenAI-compatible base URL** of the vLLM server, e.g.
  `http://192.168.100.102:8000/v1`. Only used when `inference_provider=vllm`.
  **No hardcoded IP** lives in the template — the value comes from this
  parameter, so the same template serves any vLLM host.
- **Consumed by:** `COPILOT_PROVIDER_BASE_URL`, `LOCAL_LLM_BASE_URL`, and the
  IDE BYOK scripts.

### 5. `vllm_model`
- **Type:** string | **Default:** `""` | **mutable:** yes | **order:** 5
- **What it does:** the **model name** served by vLLM, e.g. `qwen3.8-27b-fp8`
  (must match the model name vLLM advertises at `/v1/models`). Only used when
  `inference_provider=vllm`.
- **Consumed by:** `COPILOT_MODEL`, `LOCAL_LLM_MODEL`, IDE BYOK pinning, and the
  JetBrains AI Assistant preseed.

### 6. `vllm_context_window`
- **Type:** number | **Default:** `32768` | **mutable:** yes | **order:** 6
- **What it does:** the **context length** (tokens) advertised to the local
  model. Drives `LOCAL_LLM_CONTEXT_LENGTH`.
- **Usage:** set this to what the model is actually started with; an
  over-stated value can cause long prompts to exceed the model's real window.

### 7. `copilot_offline`
- **Type:** bool | **Default:** `false` | **mutable:** yes | **order:** 7
- **What it does:** maps to `COPILOT_OFFLINE`. When **true**, the Copilot CLI is
  told to keep traffic local (no calls to GitHub/Cloud), which is the correct
  posture for a **local-only** BYOK model.
- **Usage:** set **true** when `inference_provider=vllm` so the CLI never
  attempts a Cloud round-trip; leave false for the default/none setup.

### 8. `container_validation_enabled`
- **Type:** bool | **Default:** `true` | **mutable:** **no** | **order:** 8
- **What it does:** controls the **Dedicated Docker sidecar** — a privileged
  `docker:27-dind` container that gives the workspace a real in-container Docker
  daemon (shared unix socket via the `docker_sock` named volume + shared
  `/workspace-test-media` scratch via the `scratch` volume). `count` is
  `start_count * (enabled ? 1 : 0)`.
- **Usage:** keep **true** when the role needs to **run nested containers**
  (validator / staging / release-validation, or media lifecycle tests). Set
  **false** for a development workspace that does not need inner Docker — it
  removes the sidecar entirely (no `DOCKER_HOST`, no sidecar container).
- **Consumed by:** `docker_container.docker` `count`; `DOCKER_HOST` env
  (`unix:///var/run/docker/docker.sock`) is set when enabled.

### 9. `media_mount_mode`
- **Type:** string (option list) | **Default:** `none` | **mutable:** **no** | **order:** 9
- **Options:** `none` (Disabled), `read-only`.
- **What it does:** controls **real host media libraries**. When `read-only`,
  the host volumes `/media/audiobooks` and `/media/ebooks` are bind-mounted
  **read-only** into the workspace AND into the DinD sidecar at the same path,
  so inner containers can bind-mount them consistently. On `read-only`,
  `workspace-startup.sh` also runs `verify-media`.
- **Policy:** **real media is either absent or read-only.** Lifecycle/agent
  tests always work on **scratch copies** (`/workspace-test-media`), never on
  the read-only originals.
- **Consumed by:** the `dynamic "volumes"` blocks on both the workspace and
  docker containers; `MEDIA_MOUNT_MODE` env.

---

## Terraform variables (provisioner-level, not Coder parameters)

These live in `template/variables.tf` and are fixed per template version (not
shown as Coder knobs).

| Variable | Type | Default | Used for |
| --- | --- | --- | --- |
| `repository_url` | string | `https://github.com/Swartdraak/Bibliophilarr.git` | The app repo to clone at startup → `BIBLIOPHILARR_REPOSITORY_URL` → `checkout-ref.sh`. Public, so clone does not need auth. |
| `cpu` | number | `4` | Workspace container CPU shares (`cpu * 1024`). |
| `memory_gb` | number | `12` | Workspace container memory (`* 1024^3` bytes). |
| `workspace_disk_gb` | number | `40` | Workspace disk sizing (declared for the provisioner; the persistent data lives on the `home`/`nuget`/`yarn`/`scratch` named volumes, which survive stop/start). |
| (image) — note | — | — | The container image is **not** taken from a plain `var.workspace_image`; it is the `coder_parameter "workspace_image"` (above), which is the deterministic image-identity path. A plain Terraform `workspace_image` variable is intentionally **not** used for the container. |

---

## Runtime env mapping (how the parameters reach the startup scripts)

The `coder_agent "main"` env maps Coder parameters → env consumed by
`scripts/workspace-startup.sh` and the helpers:

| Env | Source | Consumed by |
| --- | --- | --- |
| `BIBLIOPHILARR_REPOSITORY_URL` | `var.repository_url` | clone + `checkout-ref.sh` |
| `BIBLIOPHILARR_REPOSITORY_DIR` | `local.project_dir` (`/workspaces/Bibliophilarr`) | clone, all IDE tools |
| `BIBLIOPHILARR_GIT_REF` | `bibliophilarr_ref` param | `checkout-ref.sh` |
| `BIBLIOPHILARR_WORKSPACE_MODE` | `workspace_mode` param | `checkout-ref.sh` (dirty-tree policy) |
| `LOCAL_LLM_PROVIDER/BASE_URL/MODEL/CONTEXT_LENGTH` | `inference_provider` + `vllm_*` | local-model gate, `verify-local-llm`, IDE BYOK, JetBrains preseed |
| `COPILOT_OFFLINE` | `copilot_offline` | Copilot CLI local-only mode |
| `COPILOT_PROVIDER_BASE_URL/TYPE/MODEL` | `inference_provider` + `vllm_*` (openai type when vllm) | Copilot CLI custom-model-provider (the local `assign-task` runtime uses this) |
| `MEDIA_MOUNT_MODE` | `media_mount_mode` | `verify-media` gate + RO media bind mounts |
| `DOCKER_HOST` | `container_validation_enabled` (when true) | in-container Docker via DinD sidecar unix socket |
| `Rider_*` / `WebStorm_*` `_config/plugins/system/log_path` | pinned to `local.coder_home` on the home volume | deterministic, persistent JetBrains remote-backend dirs (no re-download/reinstall churn) |
| `GITHUB_TOKEN` | **Coder Secret** "Swartdraak GH PAT" (`--env GITHUB_TOKEN`), auto-injected by Coder at start — **not** a template variable | `gh`/git-HTTPS auth. Never written to state/.env/logs; never printed. |

---

## Persistence model

- **Named volumes survive stop/start** (and are re-created on the same host on
  delete/recreate): `home` (`/home/coder` — JetBrains dirs, caches, gh config),
  `nuget` (`/home/coder/.nuget/packages`), `yarn` (`/home/coder/.cache/yarn`),
  `scratch` (`/workspace-test-media`), `docker_sock` (`/var/run/docker`).
- The **repository worktree** lives on the `home` volume path
  (`/workspaces/Bibliophilarr`); stop/start preserves it, so `workspace_mode`'s
  dirty-tree protection is what keeps a dev's uncommitted work safe.
- The `.nuget/packages` named volume is `mkdir`+`chown`'d to the `coder` user at
  startup (image 0.2.8+) so Rider's NuGet restore can write (it is created
  root-owned on first attach).

---

## Quick reference cards

**Development (default):**
`workspace_image`(0.2.7) · `bibliophilarr_ref=develop` · `workspace_mode=development` ·
`inference_provider=vllm` + `vllm_base_url`/`vllm_model`/`vllm_context_window` ·
`copilot_offline=true` · `container_validation_enabled=false` · `media_mount_mode=none`

**Validator (pinned commit, inner Docker, no local model needed):**
`bibliophilarr_ref=<full 40-hex SHA>` · `workspace_mode=validator` ·
`container_validation_enabled=true` · `media_mount_mode=read-only`

**Headless agent run (local model, no IDE):**
create on `workspace_image=...:0.2.9`, `inference_provider=vllm` + `vllm_*`,
`copilot_offline=true`; then `coder ssh <ws>` and run `assign-task "<bounded task>"`
(keep prompts bounded — the local 27B loops on repo-wide crawls; see IDEs.md).
