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

variable "oidc_provider_arn" {
  description = "ARN de l'OIDC provider IAM du cluster EKS (pour IRSA)"
  type        = string
}

variable "oidc_issuer_url" {
  description = "URL de l'OIDC provider du cluster EKS (sans https://)"
  type        = string
}

variable "rds_secret_arn" {
  description = "ARN du secret Secrets Manager contenant les credentials RDS"
  type        = string
}