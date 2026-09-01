data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

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
  dir                     = "/workspaces/Bibliophilarr"
  startup_script_behavior = "blocking"
  startup_script          = <<-EOT
    set -eu
    /opt/workspace/bin/workspace-startup.sh
  EOT
  env = {
    BIBLIOPHILARR_REPOSITORY_URL = var.repository_url
    BIBLIOPHILARR_REPOSITORY_DIR = "/workspaces/Bibliophilarr"
    BIBLIOPHILARR_GIT_REF        = data.coder_parameter.bibliophilarr_ref.value
    BIBLIOPHILARR_WORKSPACE_MODE = data.coder_parameter.workspace_mode.value
    LOCAL_LLM_PROVIDER           = data.coder_parameter.inference_provider.value
    LOCAL_LLM_BASE_URL           = data.coder_parameter.vllm_base_url.value
    LOCAL_LLM_MODEL              = data.coder_parameter.vllm_model.value
    LOCAL_LLM_CONTEXT_LENGTH     = data.coder_parameter.vllm_context_window.value
    COPILOT_OFFLINE              = tostring(data.coder_parameter.copilot_offline.value)
    MEDIA_MOUNT_MODE             = data.coder_parameter.media_mount_mode.value
    DOCKER_HOST                  = data.coder_parameter.container_validation_enabled.value ? "tcp://docker:2375" : ""
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
    script       = "git -C /workspaces/Bibliophilarr rev-parse --short HEAD 2>/dev/null || echo pending"
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

resource "docker_container" "workspace" {
  count      = data.coder_workspace.me.start_count
  name       = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
  image      = var.workspace_image
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
  dynamic "volumes" {
    for_each = data.coder_parameter.media_mount_mode.value == "read-only" ? toset(["audiobooks", "ebooks"]) : toset([])
    content {
      host_path      = "/media/${volumes.value}"
      container_path = "/media/${volumes.value}"
      read_only      = true
    }
  }
  tmpfs = { "/workspace-test-media" = "rw,nosuid,nodev,noexec,mode=0700,uid=1000,gid=1000,size=4g" }
  networks_advanced {
    name = docker_network.workspace.name
  }
}
resource "docker_network" "workspace" {
  name = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
}
resource "docker_container" "docker" {
  count      = data.coder_workspace.me.start_count * (data.coder_parameter.container_validation_enabled.value ? 1 : 0)
  name       = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}-docker"
  image      = "docker:27-dind-rootless"
  privileged = true
  command    = ["--host=tcp://0.0.0.0:2375", "--tls=false"]
  networks_advanced {
    name    = docker_network.workspace.name
    aliases = ["docker"]
  }
}
