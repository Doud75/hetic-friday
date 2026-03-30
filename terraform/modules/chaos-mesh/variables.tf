variable "cluster_name" {
  description = "Nom du cluster EKS"
  type        = string
}

variable "cluster_endpoint" {
  description = "Endpoint de l'API du cluster EKS"
  type        = string
}

variable "cluster_certificate_authority_data" {
  description = "Certificat CA du cluster EKS (base64)"
  type        = string
}

variable "environment" {
  description = "Environnement (dev, prod)"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "Région AWS"
  type        = string
  default     = "eu-central-1"
}

variable "target_namespace" {
  description = "Namespace Kubernetes ciblé par les expériences de chaos"
  type        = string
  default     = "hetic-friday"
}
