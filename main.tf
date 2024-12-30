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

resource "random_password" "passwords" {
  count            = 2
  length           = 64
  override_special = "!@#$%&*()-_=+[]{}<>?"

  lower   = true
  special = true
  numeric = true
  upper   = true

  min_lower   = 15
  min_special = 15
  min_numeric = 15
  min_upper   = 15
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
    POSTGRES_INITDB_ARGS              = "--data-checksums"
    POSTGRES_PASSWORD                 = "this-user-will-be-disabled"
    DATABASE_ADMIN_USER_PASSWORD      = var.database_admin_password
    DATABASE_READ_ONLY_USER_PASSWORD  = random_password.passwords[0].result
    DATABASE_READ_WRITE_USER_PASSWORD = random_password.passwords[1].result
    TZ                                = "Europe/Madrid"
    PGTZ                              = "Europe/Madrid"
  }
}