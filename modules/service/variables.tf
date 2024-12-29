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
    type           = string # Allowed values are "" (default), DirectoryOrCreate, Directory, FileOrCreate, File, Socket, CharDevice and BlockDevice
  }))
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