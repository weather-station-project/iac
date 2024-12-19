variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "name" {
  description = "Name of the service"
  type        = string
}

variable "port" {
  description = "Port of the service"
  type        = number
}

variable "volumes" {
  description = "List of volumes to mount"

  type = list(object({
    name           = string
    host_path      = string
    container_path = string
    read_only      = bool
    capacity       = string
  }))
}

variable "docker_image" {
  description = "Docker image to use"
  type        = string
}