variable "region" {
  description = "Région AWS"
  type        = string
}

variable "project_name" {
  description = "Nom du projet (utilisé pour le nommage des ressources)"
  type        = string
}

variable "environment" {
  description = "Environnement (dev, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment doit être 'dev' ou 'prod'."
  }
}

variable "vpc_id" {
  description = "ID du VPC dans lequel créer l'ALB"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs des subnets publics pour l'ALB (internet-facing)"
  type        = list(string)
}

variable "cluster_security_group_id" {
  description = "ID du security group du cluster EKS — pour ouvrir les ports des pods"
  type        = string
}

variable "cluster_name" {
  description = "Nom du cluster EKS — utilisé pour le tag eks:eks-cluster-name sur les Target Groups"
  type        = string
}

variable "cluster_endpoint" {
  description = "Endpoint du cluster EKS — pour le provider Kubernetes"
  type        = string
}

variable "cluster_certificate_authority_data" {
  description = "CA du cluster EKS (base64) — pour le provider Kubernetes"
  type        = string
}

variable "waf_whitelisted_ips" {
  description = "Liste d'IPs (CIDR) exemptes du rate-limiting WAF (load test k6, equipe)"
  type        = list(string)
  default     = []
}
