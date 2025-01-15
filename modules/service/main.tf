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

resource "kubernetes_persistent_volume" "pv" {
  for_each = { for vol in var.volumes : vol.name => vol }

  metadata {
    name = "${var.name}-${each.value.name}"
  }

  spec {
    capacity = {
      storage = each.value.capacity
    }

    access_modes = [each.value.read_only ? "ReadOnlyMany" : "ReadWriteOnce"]

    persistent_volume_source {
      host_path {
        path = each.value.host_path
        type = each.value.type
      }
    }
  }
}

resource "kubernetes_storage_class" "example" {
  for_each = { for vol in var.volumes : vol.name => vol }

  metadata {
    name = "${each.value.name}-class"
  }
  storage_provisioner = "microk8s.io/hostpath"
  reclaim_policy      = "Delete"
  volume_binding_mode = "WaitForFirstConsumer"

  parameters = {
    pvDir = each.value.host_path
  }
}

resource "kubernetes_persistent_volume_claim" "pvc" {
  for_each = { for vol in var.volumes : vol.name => vol }

  metadata {
    name      = "${var.name}-${each.value.name}"
    namespace = var.namespace
  }

  spec {
    access_modes = [each.value.read_only ? "ReadOnlyMany" : "ReadWriteOnce"]
    storage_class_name = "${each.value.name}-class"

    resources {
      requests = {
        storage = each.value.capacity
      }
    }
  }

  wait_until_bound = false
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
            for_each = { for vol in var.volumes : vol.name => vol }

            content {
              mount_path = volume_mount.value.container_path
              name       = volume_mount.value.name
            }
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
          for_each = { for vol in var.volumes : vol.name => vol }

          content {
            name = volume.value.name

            persistent_volume_claim {
              claim_name = kubernetes_persistent_volume_claim.pvc[volume.value.name].metadata[0].name
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