variable "project_name" {
  description = "Nom du projet"
  type        = string
}

variable "region" {
  description = "Région AWS"
  type        = string
}

variable "environment" {
  description = "Environnement (dev, prod)"
  type        = string
}

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

variable "eso_namespace" {
  description = "Namespace Kubernetes où tourne External Secrets Operator"
  type        = string
}