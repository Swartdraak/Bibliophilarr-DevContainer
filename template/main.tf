data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# One authoritative project path (used by code-server, JetBrains, startup,
# git ops, and the agent dir). §4: no placeholder paths.
locals {
  project_dir = "/workspaces/Bibliophilarr"
  # Coder user home, persisted on the -home named volume (survives stop/start).
  # JetBrains remote-backend dirs are pinned here so reconnects reuse them.
  coder_home = "/home/coder"
}

# NOTE on GitHub auth (§4/§25): the operator pre-created the Coder Secret
# "Swartdraak GH PAT" with --env GITHUB_TOKEN. Coder auto-injects that as the
# $GITHUB_TOKEN env var into the workspace at start (no terraform data source
# needed; there is no coder_secret data source in the coder provider). The
# startup script consumes $GITHUB_TOKEN to configure `gh`/git-HTTPS. The value
# is NEVER written to state, .env, logs, or committed.
# Precondition: `coder secret ls` must show "Swartdraak GH PAT"/GITHUB_TOKEN
# enabled, before workspace creation (runbook precondition §12/§32).

data "coder_parameter" "bibliophilarr_ref" {
  name         = "bibliophilarr_ref"
  display_name = "Git ref"
  description  = "Branch, tag, or full 40-character SHA; never falls back."
  default      = "develop"
  mutable      = true
  order        = 1
}
data "coder_parameter" "workspace_mode" {
  name         = "workspace_mode"
  display_name = "Workspace mode"
  default      = "development"
  mutable      = false
  order        = 2
  option {
    name  = "Development"
    value = "development"
  }
  option {
    name  = "CI repair"
    value = "ci-repair"
  }
  option {
    name  = "Governance"
    value = "governance"
  }
  option {
    name  = "Investigation"
    value = "investigation"
  }
  option {
    name  = "Validator"
    value = "validator"
  }
  option {
    name  = "Staging validation"
    value = "staging-validation"
  }
  option {
    name  = "Release validation"
    value = "release-validation"
  }
}
data "coder_parameter" "inference_provider" {
  name         = "inference_provider"
  display_name = "Inference provider"
  default      = "none"
  mutable      = true
  order        = 3
  option {
    name  = "None"
    value = "none"
  }
  option {
    name  = "OpenAI-compatible vLLM"
    value = "vllm"
  }
}
# workspace_image is a first-class Coder workspace input (not merely a Terraform
# default). This is the deterministic image-identity fix (§30): as a coder_parameter
# its default is refreshed from the active template version on each push, so the
# template, the requested image, the running container, WORKSPACE_IMAGE_VERSION and
# toolchain.json all identify the SAME artifact. A plain Terraform variable was being
# resolved to a stale memoized host value, so it is intentionally NOT used for the
# container image. 0.2.7 is the final clean image built from image/Dockerfile.
data "coder_parameter" "workspace_image" {
  name         = "workspace_image"
  display_name = "Workspace image"
  default      = "ghcr.io/swartdraak/bibliophilarr-agent-workspace:0.2.7"
  mutable      = true
  order        = 0
}

data "coder_parameter" "vllm_base_url" {
  name         = "vllm_base_url"
  display_name = "vLLM base URL"
  default      = ""
  mutable      = true
  order        = 4
}
data "coder_parameter" "vllm_model" {
  name         = "vllm_model"
  display_name = "vLLM model"
  default      = ""
  mutable      = true
  order        = 5
}
data "coder_parameter" "vllm_context_window" {
  name         = "vllm_context_window"
  display_name = "vLLM context window"
  type         = "number"
  default      = "32768"
  mutable      = true
  order        = 6
}
data "coder_parameter" "copilot_offline" {
  name         = "copilot_offline"
  display_name = "Local model traffic only"
  type         = "bool"
  default      = false
  mutable      = true
  order        = 7
}
data "coder_parameter" "container_validation_enabled" {
  name         = "container_validation_enabled"
  display_name = "Dedicated Docker sidecar"
  type         = "bool"
  default      = true
  mutable      = false
  order        = 8
}
data "coder_parameter" "media_mount_mode" {
  name         = "media_mount_mode"
  display_name = "Host media libraries"
  description  = "Real media is either absent or mounted read-only. Lifecycle tests always use scratch copies."
  default      = "none"
  mutable      = false
  order        = 9
  option {
    name  = "Disabled"
    value = "none"
  }
  option {
    name  = "Read-only"
    value = "read-only"
  }
}

resource "coder_agent" "main" {
  arch                    = "amd64"
  os                      = "linux"
  dir                     = local.project_dir
  startup_script_behavior = "blocking"
  startup_script          = <<-EOT
    set -eu
    # §4 NuGet restore fix: the `nuget` named volume mounts at /home/coder/.nuget/packages.
    # On FIRST attach of an empty Docker named volume, docker creates it root-owned, so
    # Rider's NuGet restore (running as the `coder` user) fails:
    #   "Access to the path '/home/coder/.nuget/packages/...' is denied. (Permission denied)"
    # This startup script runs as the `coder` user; ensure the package-cache dir is
    # coder-owned so restore/build succeed. Best-effort (non-fatal): if the dir is still
    # not ours (edge: a prior root-owned mount), the line is skipped and the user can
    # re-run; it self-heals on the next coder-owned run. Never blocks startup.
    mkdir -p /home/coder/.nuget/packages 2>/dev/null || true
    chown -R "$(id -u):$(id -g)" /home/coder/.nuget 2>/dev/null || true
    /opt/workspace/bin/workspace-startup.sh
  EOT
  env = {
    BIBLIOPHILARR_REPOSITORY_URL = var.repository_url
    BIBLIOPHILARR_REPOSITORY_DIR = local.project_dir
    BIBLIOPHILARR_GIT_REF        = data.coder_parameter.bibliophilarr_ref.value
    BIBLIOPHILARR_WORKSPACE_MODE = data.coder_parameter.workspace_mode.value
    LOCAL_LLM_PROVIDER           = data.coder_parameter.inference_provider.value
    LOCAL_LLM_BASE_URL           = data.coder_parameter.vllm_base_url.value
    LOCAL_LLM_MODEL              = data.coder_parameter.vllm_model.value
    LOCAL_LLM_CONTEXT_LENGTH     = data.coder_parameter.vllm_context_window.value
    COPILOT_OFFLINE              = tostring(data.coder_parameter.copilot_offline.value)
    # ByokProvider (official Copilot CLI custom-model-provider env; see
    # docs.github.com/.../customize-copilot/use-byok-models). This is the
    # LOCAL Qwen/vLLM custom-agent runtime — it is intentionally SEPARATE from
    # GitHub cloud auth. When the selected provider is the OpenAI-compatible
    # local vLLM, map our Coder params to the COPILOT_PROVIDER_* vars so
    # `copilot --agent <name>` / custom-agent delegation use the local model.
    # COPILOT_PROVIDER_API_KEY is omitted: the docs state it is "not required
    # for providers that do not use authentication, such as a local Ollama
    # instance" — and a keyless local vLLM needs none. We do NOT invent extra
    # vars or reference GITHUB_TOKEN here.
    COPILOT_PROVIDER_BASE_URL = data.coder_parameter.inference_provider.value == "vllm" ? data.coder_parameter.vllm_base_url.value : ""
    COPILOT_PROVIDER_TYPE     = data.coder_parameter.inference_provider.value == "vllm" ? "openai" : ""
    COPILOT_MODEL             = data.coder_parameter.inference_provider.value == "vllm" ? data.coder_parameter.vllm_model.value : ""
    MEDIA_MOUNT_MODE          = data.coder_parameter.media_mount_mode.value
    DOCKER_HOST               = data.coder_parameter.container_validation_enabled.value ? "unix:///var/run/docker/docker.sock" : ""
    # §8 JetBrains backend determinism: force the Coder JetBrains remote
    # backend (Rider/WebStorm) to use PERSISTENT config/plugins/system paths on
    # the home volume, so reconnects do NOT re-download the build or reinstall
    # plugins (the root cause of the "Channel closed / executor rejected /
    # re-download on first launch" churn). These are documented JetBrains IDE
    # dir-override env vars (<product>.config.path / .plugins.path / .system.path
    # / .log.path); product codes match the jetbrains module (RD=Rider,
    # WS=WebStorm -> env uses the human product name Rider/WebStorm). Persisted
    # as long as the home volume persists (stop/start); a delete/recreate
    # re-seeds via the startup preparation step (apply-jetbrains-backend.sh).
    Rider_config_path     = "${local.coder_home}/.config/JetBrains/Rider"
    Rider_plugins_path    = "${local.coder_home}/.local/share/JetBrains/Rider"
    Rider_system_path     = "${local.coder_home}/.cache/JetBrains/Rider"
    Rider_log_path        = "${local.coder_home}/.cache/JetBrains/Rider/log"
    WebStorm_config_path  = "${local.coder_home}/.config/JetBrains/WebStorm"
    WebStorm_plugins_path = "${local.coder_home}/.local/share/JetBrains/WebStorm"
    WebStorm_system_path  = "${local.coder_home}/.cache/JetBrains/WebStorm"
    WebStorm_log_path     = "${local.coder_home}/.cache/JetBrains/WebStorm/log"
    # NOTE: GITHUB_TOKEN is NOT set here. It is auto-injected by Coder from the
    # operator's Coder Secret "Swartdraak GH PAT" (--env GITHUB_TOKEN) at
    # workspace start. The startup script uses $GITHUB_TOKEN to configure `gh`
    # / git-HTTPS. (No `coder_secret` terraform data source exists.)
  }
  metadata {
    display_name = "Mode"
    key          = "mode"
    script       = "echo ${data.coder_parameter.workspace_mode.value}"
    interval     = 0
  }
  metadata {
    display_name = "Repository HEAD"
    key          = "head"
    script       = "git -C ${local.project_dir} rev-parse --short HEAD 2>/dev/null || echo pending"
    interval     = 60
  }
  metadata {
    display_name = "Docker"
    key          = "docker"
    script       = "docker info >/dev/null 2>&1 && echo available || echo unavailable"
    interval     = 60
  }
}

resource "docker_volume" "home" {
  name = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}-home"
  lifecycle {
    ignore_changes = all
  }
}
resource "docker_volume" "nuget" {
  name = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}-nuget"
  lifecycle {
    ignore_changes = all
  }
}
resource "docker_volume" "yarn" {
  name = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}-yarn"
  lifecycle {
    ignore_changes = all
  }
}
# Shared scratch media storage. Mounted at the same /workspace-test-media path
# in BOTH the main workspace and the DinD sidecar so that inner containers can
# bind-mount scratch read/write consistently with the workspace (Phases 31/33).
resource "docker_volume" "scratch" {
  name = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}-scratch"
  lifecycle {
    ignore_changes = all
  }
}
# Shared Docker API socket between the main workspace and the DinD sidecar.
# The sidecar (privileged, root) runs the daemon on a unix socket inside this
# volume; the non-root workspace container talks to the same socket. A shared
# named volume is required because docker:27-dind serves TLS on its TCP port,
# so a unix socket is the only transport that works without cert management.
resource "docker_volume" "docker_sock" {
  name = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}-docker-sock"
  lifecycle {
    ignore_changes = all
  }
}

resource "docker_container" "workspace" {
  count      = data.coder_workspace.me.start_count
  name       = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
  image      = data.coder_parameter.workspace_image.value
  hostname   = data.coder_workspace.me.name
  cpu_shares = var.cpu * 1024
  memory     = var.memory_gb * 1024 * 1024 * 1024
  env        = ["CODER_AGENT_TOKEN=${coder_agent.main.token}"]
  command    = ["sh", "-c", coder_agent.main.init_script]
  volumes {
    volume_name    = docker_volume.home.name
    container_path = "/home/coder"
  }
  volumes {
    volume_name    = docker_volume.nuget.name
    container_path = "/home/coder/.nuget/packages"
  }
  volumes {
    volume_name    = docker_volume.yarn.name
    container_path = "/home/coder/.cache/yarn"
  }
  volumes {
    volume_name    = docker_volume.scratch.name
    container_path = "/workspace-test-media"
  }
  volumes {
    volume_name    = docker_volume.docker_sock.name
    container_path = "/var/run/docker"
  }
  dynamic "volumes" {
    for_each = data.coder_parameter.media_mount_mode.value == "read-only" ? toset(["audiobooks", "ebooks"]) : toset([])
    content {
      host_path      = "/media/${volumes.value}"
      container_path = "/media/${volumes.value}"
      read_only      = true
    }
  }
  # v0.7 fix (evidence-based, from the minimal agent smoke test): use the
  # DEFAULT bridge network instead of a Coder-managed custom network. The
  # custom network made the workspace container unable to reach the Coder
  # server for the agent bootstrap (curl: (3) URL rejected: Bad hostname), so
  # the agent stuck in "connecting". The default bridge is proven to reach the
  # Coder server. The DinD socket and scratch are shared via NAMED VOLUMES,
  # which are daemon-scoped and do NOT require a shared custom network.
  networks_advanced {
    name = "bridge"
  }
}
resource "docker_container" "docker" {
  count      = data.coder_workspace.me.start_count * (data.coder_parameter.container_validation_enabled.value ? 1 : 0)
  name       = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}-docker"
  image      = "docker:27-dind"
  privileged = true
  # Locally proven architecture (Phase 26/31/32/33):
  #   * docker:27-dind serves TLS on its TCP API port, so we use a unix socket
  #     on a shared named volume (docker_sock) instead of plaintext TCP.
  #   * The socket's default 0660 root:docker perms would lock out the non-root
  #     workspace user; a root loop keeps it 0666.
  #   * The shared scratch volume is created root-owned (the sidecar touches it
  #     first); chown it to 1000:1000 (the workspace coder user) so the
  #     non-root workspace can write scratch and inner containers (root, via
  #     the daemon) can read it.
  #
  # COMMAND NOTE (fast-containerd bridge; root-cause fix for the 2026-09-02 nested
  # DinD failure). Symptom on a Proxmox/ZFS host: the nested dockerd log read
  #   "containerd successfully booted in ~10.1s"
  #   "stopping healthcheck following graceful shutdown"
  #   "failed to start containerd: timeout waiting for containerd to start"
  # Root cause: containerd's zfs/aufs/blockfile/devmapper SNAPSHOTTER PLUGINS are
  # probed at boot; on this ZFS host the zfs probe runs `zfs list` against the
  # pool (~10s), so total containerd boot exceeds Docker's managed-containerd
  # libcontainerd startup healthcheck window, and dockerd aborts with the false
  # "timeout" even though containerd DID boot. This reproduced identically in a
  # manually-run docker:27-dind on the same host, so it is a HOST_RUNTIME property
  # (slow containerd startup), NOT a Coder/provider difference.
  #
  # Fix (minimal, command-only): pre-seed a containerd config that disables the
  # irrelevant slow snapshotters (overlay2 is the actual driver), run containerd
  # with it (~0.06s boot), then run dockerd --containerd=<sock> against that
  # external containerd so dockerd does not launch its own (healthchecked)
  # managed containerd. Keeps: privilege, bridge network, shared scratch/sock
  # volumes, RO media mounts, and the socket-chmod keep-alive. No new resources.
  command = ["sh", "-c", "chown -R 1000:1000 /workspace-test-media 2>/dev/null || true; mkdir -p /etc/containerd && printf 'version = 2\\n[plugins.\"io.containerd.snapshotter.v1.blockfile\"]\\n  disable = true\\n[plugins.\"io.containerd.snapshotter.v1.devmapper\"]\\n  disable = true\\n[plugins.\"io.containerd.snapshotter.v1.aufs\"]\\n  disable = true\\n[plugins.\"io.containerd.snapshotter.v1.zfs\"]\\n  disable = true\\n' > /etc/containerd/fast.toml; /usr/local/bin/containerd --config /etc/containerd/fast.toml >/tmp/containerd.log 2>&1 & for i in $(seq 1 20); do if [ -S /var/run/containerd/containerd.sock ]; then break; fi; sleep 1; done; sleep 2; dockerd --containerd=/var/run/containerd/containerd.sock --host=unix:///var/run/docker/docker.sock >/tmp/dind.log 2>&1 & while :; do if [ -S /var/run/docker/docker.sock ]; then chmod 0666 /var/run/docker/docker.sock 2>/dev/null || true; fi; sleep 1; done"]
  # The DinD daemon's bind mounts resolve against the host paths below.
  volumes {
    volume_name    = docker_volume.scratch.name
    container_path = "/workspace-test-media"
  }
  volumes {
    volume_name    = docker_volume.docker_sock.name
    container_path = "/var/run/docker"
  }
  dynamic "volumes" {
    for_each = data.coder_parameter.media_mount_mode.value == "read-only" ? toset(["audiobooks", "ebooks"]) : toset([])
    content {
      host_path      = "/media/${volumes.value}"
      container_path = "/media/${volumes.value}"
      read_only      = true
    }
  }
  # Same default bridge as the workspace container (v0.7). They share the DinD
  # socket and scratch through named volumes, not through a custom network.
  networks_advanced {
    name = "bridge"
  }
}

# ---------------------------------------------------------------------------
# IDE integrations (official Coder Registry modules). §2/§3/§4: these surface
# Coder dashboard apps (code-server + JetBrains) against the REAL project dir.
# Versions are EXACT-pinned (not `latest`, not `~>`) per the deterministic
# toolchain policy: a future template init must not silently select a different
# module minor version. See toolchain.json + docs/IDEs.md. §8: the generic
# git-clone module is intentionally NOT used - the custom checkout-ref.sh
# supports exact-SHA + dirty-worktree protection it lacks.
#
# JetBrains 1.4.0 note: the module's ide_config validation
#   (var.ide_config == null || length(var.ide_config) > 0)
# evaluates length() on the null default during template-import plan and
# fails with "argument must not be null" (a module bug when ide_config is
# null). We therefore supply a NON-NULL ide_config with pinned Rider/WebStorm
# build numbers: this is the module's documented air-gapped/pinning path,
# it makes plan deterministic (no live JetBrains API HTTP call at plan time),
# and it fixes the null. options/default use product codes (RD=Rider, WS=
# WebStorm) per the module's accepted codes.
# ---------------------------------------------------------------------------
# code-server is scoped as a BROWSER EDITOR / TERMINAL / Git / Docker /
# Copilot CLI / local Qwen-via-CLI surface (NOT Microsoft Copilot Agent Mode).
# It is a Coder development environment (not an arbitrary untrusted repo), so
# the workspace-trust step is DISABLED deterministically. --disable-workspace-trust
# on the CLI plus the user setting cover the startup path; telemetry off for a
# controlled environment. (§9)
#
# §5 extension split: the required REMOTE extensions (csdevkit C#, Docker,
# Python, ESLint, Copilot) are the VS Code DESKTOP remote surface (read by
# Desktop from .devcontainer/devcontainer.json on connect). code-server is the
# OSS VS Code build and cannot resolve/install several Desktop-only extensions
# (csdevkit, remote-containers, Copilot chat) — forcing auto_install makes its
# startup report extension-install failures. code-server is intentionally NOT the
# C# surface, so it does not auto-install that desktop inventory (reproducible
# via .devcontainer for VS Code Desktop).
module "code-server" {
  count                   = data.coder_workspace.me.start_count
  source                  = "registry.coder.com/coder/code-server/coder"
  version                 = "1.5.2"
  agent_id                = coder_agent.main.id
  folder                  = local.project_dir
  order                   = 1
  auto_install_extensions = false
  additional_args         = "--disable-workspace-trust"
  settings = {
    "security.workspace.trust.enabled"        = false
    "security.workspace.trust.untrustedFiles" = "open"
    "telemetry.level"                         = "off"
    "workbench.startupEditor"                 = "welcome"
  }
}

module "jetbrains" {
  count      = data.coder_workspace.me.start_count
  source     = "registry.coder.com/coder/jetbrains/coder"
  version    = "1.4.0"
  agent_id   = coder_agent.main.id
  agent_name = "main"
  folder     = local.project_dir
  # Rider (.NET) + WebStorm (Node) are the intended Bibliophilarr IDEs (IDEs.md).
  # Product codes per the jetbrains module (RD=Rider, WS=WebStorm).
  options = toset(["RD", "WS"])
  default = toset(["RD", "WS"])
  tooltip = "Open Bibliophilarr in Rider or WebStorm via JetBrains Toolbox"
  # Non-null (PINNED) — and it MUST stay non-null; do NOT switch to
  # ide_config = null (dynamic latest-stable). Root cause of the historical
  # "length(null) / Invalid value for 'value' parameter: argument must not be
  # null" plan error (re-investigated 2026-09-04): the jetbrains module's own
  # validation line
  #     condition = var.ide_config == null || length(var.ide_config) > 0
  # is NOT safe on the Terraform this repo's CI actually pins (1.9.8): older
  # Terraform evaluates length(null) before the || can short-circuit, so null
  # fails validate/plan. On newer Terraform (1.10+/1.16 local) it short-circuits
  # and SUCCEEDS (observed RD->262.9437.287, WS->262.10315.144), which MASKS
  # the module bug when testing locally. It is a module-side validation bug, not
  # a template bug; we do not modify/upgrade the module (1.4.0 is latest) per
  # policy, so we pin exact build numbers instead and refresh them to current
  # latest-stable when a new stable ships (that IS the no-exact-REPRO-pin policy:
  # track latest stable, don't freeze an old patch indefinitely).
  # Real latest stable builds (majorVersion 2026.2), fetched from
  # data.services.jetbrains.com on 2026-09-02. When ide_config is set,
  # major_version/channel/release links must stay at their defaults (not passed
  # here, per the module's validation).
  #
  # Plugin handling (FIRST-LAUNCH, corrected 2026-09-04 after live testing):
  # The Coder JetBrains module has NO plugin-install hook, so it does NOT
  # force-install the GitHub Copilot plugin or JetBrains AI Assistant. This is
  # deliberate (least privilege). Live first-launch on the pinned Rider
  # 262.9437.287 (2026.2) showed the auto-installed GitHub Copilot plugin
  # 1.8.2-243 CRASHED: NoClassDefFoundError com/intellij/openapi/vcs/
  # ProjectLevelVcsManager (a plugin-vs-IDE-build compatibility defect, not
  # caused by this template). Forcing a known-incompatible plugin into the
  # pinned build would break first launch, so we intentionally do NOT pre-install
  # it. The proven in-workspace local-model + custom-agent surface is VS Code /
  # code-server / Copilot CLI (see scripts/apply-ide-byok.sh + register-copilot-mcp.sh).
  ide_config = {
    RD = { build = "262.9437.287", name = "Rider", icon = "/icon/rider.svg" }
    WS = { build = "262.9437.145", name = "WebStorm", icon = "/icon/webstorm.svg" }
  }
}
