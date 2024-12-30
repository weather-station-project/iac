variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "database_admin_password" {
  description = "Database admin password"
  type        = string
  sensitive   = true
}