variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "sa_role" {
  description = "Service account role"
  type        = string
}

variable "name" {
  description = "Name of the service"
  type        = string
}

variable "container_port" {
  description = "Internal port of the container"
  type        = number
}

variable "external_port" {
  description = "External port of the service"
  type        = number
}

variable "config_maps" {
  description = "List of config maps to mount"

  type = list(object({
    name              = string
    content_file_path = string
    container_path    = string
    file_name         = string
  }))

  default = []
}

variable "docker_image" {
  description = "Docker image to use"
  type        = string
}

variable "environment_variables" {
  description = "Environment variables to set"
  type        = map(string)
  sensitive   = true
}