terraform {
  required_version = ">= 1.5"
  required_providers {
    coder  = { source = "coder/coder", version = "~> 2.6" }
    docker = { source = "kreuzwerker/docker", version = "~> 3.0" }
  }
}
provider "coder" {}
provider "docker" {}
