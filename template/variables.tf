variable "workspace_image" {
  description = "Immutable workspace image tag or digest."
  type        = string
  # 0.2.9 = the current committed image built from the repository Dockerfile
  # and published to GHCR. It includes the assign-task loop-guard fix, the
  # code-server cache ownership fix, the safe ENTRYPOINT/CMD fix, and the
  # repository validation scripts. Keep the template default pinned to an exact
  # immutable tag; never use latest.
  default = "ghcr.io/swartdraak/bibliophilarr-agent-workspace:0.2.9"
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
