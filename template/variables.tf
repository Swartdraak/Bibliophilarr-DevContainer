variable "workspace_image" {
  description = "Immutable workspace image tag or digest."
  type        = string
  # 0.2.6 = the final clean image built from the repository Dockerfile (the
  # source of truth). It carries ALL proven fixes: safe empty ENTRYPOINT +
  # fallback CMD, USER=coder/UID1000, coder-owned home/cache (the code-server
  # install fix), the §27 fresh-clone checkout fix, media-common sourcing,
  # Codex CLI 0.152.1, Copilot CLI, GitHub CLI, Docker client/Compose, the
  # image self-test, and the verify scripts. It is NOT produced by any ad-hoc
  # overlay or host retag; the committed Dockerfile + scripts reproduce it.
  # 0.2.3 / 0.2.4 are retained on the daemon as rollback artifacts (not retagged).
  default = "ghcr.io/swartdraak/bibliophilarr-agent-workspace:0.2.6"
  validation {
    condition     = var.workspace_image != "latest" && !endswith(var.workspace_image, ":latest")
    error_message = "Pin an immutable version or digest, never latest."
  }
}
variable "repository_url" {
  type    = string
  default = "https://github.com/Swartdraak/Bibliophilarr.git"
}
variable "cpu" {
  type    = number
  default = 4
}
variable "memory_gb" {
  type    = number
  default = 12
}
variable "workspace_disk_gb" {
  type    = number
  default = 40
}
