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