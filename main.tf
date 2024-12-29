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
      name           = "timezone"
      host_path      = "/etc/timezone"
      container_path = "/etc/timezone"
      read_only      = true
      capacity       = "1Mi"
      type           = "File"
    },
    {
      name           = "localtime"
      host_path      = "/etc/localtime"
      container_path = "/etc/localtime"
      read_only      = true
      capacity       = "1Mi"
      type           = "File"
    }
  ]

  environment_variables = {
    POSTGRES_INITDB_ARGS = "--data-checksums"
    TZ                   = "Europe/Madrid"
    PGTZ                 = "Europe/Madrid"
  }
}