resource "kubernetes_service_account" "service_account" {
  metadata {
    name      = "${var.name}-sa"
    namespace = var.namespace
  }
}

resource "kubernetes_role_binding" "pod_executor_binding" {
  metadata {
    name      = "${var.sa_role}-${kubernetes_service_account.service_account.metadata[0].name}-binding"
    namespace = var.namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = var.sa_role
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.service_account.metadata[0].name
    namespace = var.namespace
  }
}

resource "kubernetes_service" "service" {
  metadata {
    name      = var.name
    namespace = var.namespace
  }

  spec {
    type       = "NodePort"
    cluster_ip = null

    port {
      port        = var.container_port
      target_port = var.container_port
      node_port   = var.external_port
      protocol    = "TCP"
    }

    selector = {
      app = var.name
    }
  }
}

resource "kubernetes_config_map" "config_map" {
  for_each = { for cm in var.config_maps : cm.name => cm }

  metadata {
    name      = each.key
    namespace = var.namespace
  }

  data = {
    (each.value.file_name) = file(each.value.content_file_path)
  }
}

resource "kubernetes_stateful_set" "statefulset" {
  metadata {
    name      = var.name
    namespace = var.namespace
  }

  spec {
    service_name = var.name
    replicas     = 1

    selector {
      match_labels = {
        app = var.name
      }
    }

    template {
      metadata {
        labels = {
          app = var.name
        }
      }

      spec {
        service_account_name = kubernetes_service_account.service_account.metadata[0].name
        restart_policy       = "Always"

        container {
          name              = var.name
          image             = var.docker_image
          image_pull_policy = "Always"

          port {
            container_port = var.container_port
            protocol       = "TCP"
          }

          dynamic "volume_mount" {
            for_each = { for cm in var.config_maps : cm.name => cm }

            content {
              name       = volume_mount.value.name
              mount_path = volume_mount.value.container_path
              sub_path   = volume_mount.value.file_name
            }
          }

          dynamic "env" {
            for_each = var.environment_variables

            content {
              name  = env.key
              value = env.value
            }
          }
        }

        dynamic "volume" {
          for_each = { for cm in var.config_maps : cm.name => cm }

          content {
            name = volume.value.name

            config_map {
              name = volume.value.name
            }
          }
        }
      }
    }
  }
}