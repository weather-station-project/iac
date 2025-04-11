provider "kubernetes" {}

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.34.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "3.6.3"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "4.0.6"
    }

    helm = {
      source = "hashicorp/helm"
      version = "2.17.0"
    }
  }

  backend "kubernetes" {}
}