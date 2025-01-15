variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "time_zone" {
  description = "Time zone to set in the containers"
  type        = string
}

variable "database_admin_password" {
  description = "Database admin password"
  type        = string
  sensitive   = true
}

variable "database_size_limit" {
  description = "Database size to use as maximum"
  type        = string
}

variable "backend_image_tag" {
  description = "Backend image tag"
  type        = string
}