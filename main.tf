provider "kubernetes" {}

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.34.0"
    }
  }

  backend "kubernetes" {}
}

resource "kubernetes_namespace" "namespace" {
  metadata {
    name = var.namespace
  }
}

module "service" {
  source = "./modules/service"

  namespace    = var.namespace
  name         = "database"
  docker_image = "postgres:17-alpine"
  port         = 5432

  volumes = [
    {
      name           = "TimeZone"
      host_path      = "/etc/timezone"
      container_path = "/etc/timezone"
      read_only      = true
      capacity       = "1Ki"
    },
    {
      name           = "LocalTime"
      host_path      = "/etc/localtime"
      container_path = "/etc/localtime"
      read_only      = true
      capacity       = "1Ki"
    }
  ]
}