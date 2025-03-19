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

    tls = {
      source  = "hashicorp/tls"
      version = "4.0.6"
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
  count            = 4
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

locals {
  hostname                          = "raspberrypi"
  database_read_only_user_password  = random_password.passwords[0].result
  database_read_write_user_password = random_password.passwords[1].result
  jwt_secret                        = random_password.passwords[2].result
  socket_server_admin_password      = random_password.passwords[3].result
  certificates_folder               = "/etc/ssl/certs"
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

resource "tls_private_key" "key" {
  algorithm = "ED25519"
}

resource "tls_self_signed_cert" "certificate" {
  key_algorithm   = "ED25519"
  private_key_pem = tls_private_key.key.private_key_pem
  allowed_uses    = ["server_auth"]

  subject {
    common_name  = "wsp.com"
    organization = "Weather Station Project"
    country      = "Spain"
    province     = "Madrid"
    locality     = "Madrid"
  }

  validity_period_hours = 175200 # 20 years
}

resource "kubernetes_secret" "certificate_secret" {
  metadata {
    name      = "certificate-secret"
    namespace = kubernetes_namespace.namespace.metadata[0].name
  }

  data = {
    tls.crt = tls_self_signed_cert.certificate.cert_pem
    tls.key = tls_private_key.key.private_key_pem
  }

  type = "kubernetes.io/tls"
}

module "database" {
  source = "github.com/davidleonm/cicd-pipelines/terraform/modules/service"

  namespace      = kubernetes_namespace.namespace.metadata[0].name
  name           = "database"
  docker_image   = "postgres:17-alpine"
  container_port = 5432
  external_port  = 30032
  sa_role        = kubernetes_role.pod_executor.metadata[0].name
  hostname       = local.hostname

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

  security_context = {
    run_as_user     = 1000
    run_as_group    = 1003
    fs_group        = 1003
    run_as_non_root = true
  }

  environment_variables = {
    POSTGRES_INITDB_ARGS              = "--data-checksums"
    POSTGRES_PASSWORD                 = "this-user-will-be-disabled"
    DATABASE_ADMIN_USER_PASSWORD      = var.database_admin_password
    DATABASE_READ_ONLY_USER_PASSWORD  = local.database_read_only_user_password
    DATABASE_READ_WRITE_USER_PASSWORD = local.database_read_write_user_password
    TZ                                = var.time_zone
    PGTZ                              = var.time_zone
  }
}

module "backend" {
  source     = "github.com/davidleonm/cicd-pipelines/terraform/modules/service"
  depends_on = [module.database]

  namespace      = kubernetes_namespace.namespace.metadata[0].name
  name           = "backend"
  docker_image   = "weatherstationproject/backend:${var.backend_image_tag}"
  container_port = 8443
  external_port  = 30080
  sa_role        = kubernetes_role.pod_executor.metadata[0].name
  hostname       = local.hostname

  environment_variables = {
    PORT                = "8443"
    NODE_ENV            = "production"
    JWT_SECRET          = local.jwt_secret
    JWT_EXPIRATION_TIME = "1h"
    LOG_LEVEL           = "info"
    TZ                  = var.time_zone

    DATABASE_HOST     = module.database.fully_qualified_name
    DATABASE_NAME     = "weather_station"
    DATABASE_USER     = "read_write"
    DATABASE_PASSWORD = local.database_read_write_user_password
    DATABASE_SCHEMA   = "weather_station"

    KEY_FILE  = "${local.certificates_folder}/tls.key"
    CERT_FILE = "${local.certificates_folder}/tls.crt"
  }

  security_context = {
    run_as_user     = 1000
    run_as_group    = 1003
    fs_group        = 1003
    run_as_non_root = true
  }

  secret_volumes = [
    {
      name           = "certificates"
      secret_name    = kubernetes_secret.certificate_secret.metadata[0].name
      container_path = local.certificates_folder
      read_only      = true
    }
  ]
}

module "socket_server" {
  source = "github.com/davidleonm/cicd-pipelines/terraform/modules/service"

  namespace      = kubernetes_namespace.namespace.metadata[0].name
  name           = "socket-server"
  docker_image   = "weatherstationproject/socket-server:${var.socket_server_image_tag}"
  container_port = 8080
  external_port  = 30081
  sa_role        = kubernetes_role.pod_executor.metadata[0].name
  hostname       = local.hostname

  environment_variables = {
    PORT                = "8080"
    NODE_ENV            = "production"
    JWT_SECRET          = local.jwt_secret
    JWT_EXPIRATION_TIME = "1h"
    LOG_LEVEL           = "info"
    ADMIN_PASSWORD      = local.socket_server_admin_password
    TZ                  = var.time_zone
  }

  security_context = {
    run_as_user     = 1000
    run_as_group    = 1003
    fs_group        = 1003
    run_as_non_root = true
  }
}

module "web_ui" {
  source = "github.com/davidleonm/cicd-pipelines/terraform/modules/service"

  namespace      = kubernetes_namespace.namespace.metadata[0].name
  name           = "web-ui"
  docker_image   = "weatherstationproject/web-ui:${var.web_ui_image_tag}"
  container_port = 5173
  external_port  = 30082
  sa_role        = kubernetes_role.pod_executor.metadata[0].name
  hostname       = local.hostname

  environment_variables = {
    NODE_ENV     = "production"
    DNS_RESOLVER = "kube-dns.kube-system.svc.cluster.local"
    BACKEND_URL  = "https://${module.backend.fully_qualified_name}:${module.backend.container_port}"
    SOCKET_URL   = "http://${module.socket_server.fully_qualified_name}:${module.backend.container_port}"
    LOGIN        = "dashboard"
    PASSWORD     = local.database_read_only_user_password
    TZ           = var.time_zone
  }
}