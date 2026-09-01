variable "workspace_image" {
  description = "Immutable workspace image tag or digest."
  type        = string
  default     = "ghcr.io/swartdraak/bibliophilarr-agent-workspace:0.2.1"
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
