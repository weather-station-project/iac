resource "kubernetes_role" "pod_executor" {
  metadata {
    name      = "pod-executor"
    namespace = var.namespace
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

resource "kubernetes_service_account" "service_account" {
  metadata {
    name      = "${var.name}-sa"
    namespace = var.namespace
  }
}

resource "kubernetes_role_binding" "pod_executor_binding" {
  metadata {
    name      = "pod-executor-binding"
    namespace = var.namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.pod_executor.metadata[0].name
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
      port        = var.port
      target_port = var.port
    }

    selector = {
      app = var.name
    }
  }
}

resource "kubernetes_persistent_volume" "pv" {
  for_each = var.volumes

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

resource "kubernetes_persistent_volume_claim" "pvc" {
  for_each = var.volumes

  metadata {
    name      = "${var.name}-${each.value.name}"
    namespace = var.namespace
  }

  spec {
    access_modes = [each.value.read_only ? "ReadOnlyMany" : "ReadWriteOnce"]

    resources {
      requests = {
        storage = each.value.capacity
      }
    }
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

        container {
          name              = var.name
          image             = var.docker_image
          image_pull_policy = "IfNotPresent"

          port {
            container_port = var.port
            protocol       = "TCP"
          }

          dynamic "volume_mount" {
            for_each = var.volumes

            content {
              mount_path = volume_mount.value.container_path
              name       = volume_mount.value.name
            }
          }
        }
      }
    }

    dynamic "volume" {
      for_each = var.volumes

      content {
        name = volume.value.name

        persistent_volume_claim = {
          claim_name = kubernetes_persistent_volume_claim.pvc[volume.value.name].metadata[0].name
        }
      }
    }
  }
}