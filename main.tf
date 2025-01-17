provider "kubernetes" {}

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.34.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "3.6.3"
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
  count            = 3
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

resource "kubernetes_role" "pod_executor" {
  metadata {
    name      = "pod-executor"
    namespace = kubernetes_namespace.namespace.metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["create"]
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get"]
  }
}

resource "kubernetes_storage_class" "weather_station_storage" {
  metadata {
    name = "weather-station-storage"
  }

  storage_provisioner = "microk8s.io/hostpath"
  reclaim_policy      = "Retain"
  volume_binding_mode = "WaitForFirstConsumer"

  parameters = {
    pvDir = var.environment_root_folder
  }
}

module "database" {
  source = "github.com/davidleonm/cicd-pipelines/terraform/modules/service"

  namespace      = kubernetes_namespace.namespace.metadata[0].name
  name           = "database"
  docker_image   = "postgres:17-alpine"
  container_port = 5432
  external_port  = 30032
  sa_role        = kubernetes_role.pod_executor.metadata[0].name

  config_maps = [
    {
      name              = "database-init-script"
      file_name         = "init.sh"
      content_file_path = "./db/init.sh"
      container_path    = "/docker-entrypoint-initdb.d/init.sh"
    }
  ]

  volumes = [
    {
      name               = "data"
      storage_class_name = kubernetes_storage_class.weather_station_storage.metadata[0].name
      host_path          = "${var.environment_root_folder}/database"
      container_path     = "/var/lib/postgresql/data"
      read_only          = false
      capacity           = var.database_size_limit
    }
  ]

  environment_variables = {
    POSTGRES_INITDB_ARGS              = "--data-checksums"
    POSTGRES_PASSWORD                 = "this-user-will-be-disabled"
    DATABASE_ADMIN_USER_PASSWORD      = var.database_admin_password
    DATABASE_READ_ONLY_USER_PASSWORD  = random_password.passwords[0].result
    DATABASE_READ_WRITE_USER_PASSWORD = random_password.passwords[1].result
    TZ                                = var.time_zone
    PGTZ                              = var.time_zone
  }
}

module "backend" {
  source     = "github.com/davidleonm/cicd-pipelines/terraform/modules/service"
  depends_on = [module.database]

  namespace      = var.namespace
  name           = "backend"
  docker_image   = "weatherstationproject/backend:${var.backend_image_tag}"
  container_port = 8080
  external_port  = 30080
  sa_role        = kubernetes_role.pod_executor.metadata[0].name

  environment_variables = {
    NODE_ENV            = "production"
    JWT_SECRET          = random_password.passwords[2].result
    JWT_EXPIRATION_TIME = "1h"
    LOG_LEVEL           = "info"
    DATABASE_HOST       = module.database.service_name
    DATABASE_NAME       = "weather_station"
    DATABASE_USER       = "read_write"
    DATABASE_PASSWORD   = random_password.passwords[1].result
    DATABASE_SCHEMA     = "weather_station"
    TZ                  = var.time_zone
  }
}