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

variable "environment_root_folder" {
  description = "Root folder for environment files"
  type        = string
}

variable "backend_image_tag" {
  description = "Backend image tag"
  type        = string
}

variable "socket_server_image_tag" {
  description = "Socket server image tag"
  type        = string
}

variable "web_ui_image_tag" {
  description = "Web UI image tag"
  type        = string
}