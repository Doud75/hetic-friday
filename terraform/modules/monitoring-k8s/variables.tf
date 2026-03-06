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

variable "project_name" {
  description = "Nom du projet"
  type        = string
  default     = "hetic_friday_g2"
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

variable "grafana_admin_password" {
  description = "Mot de passe admin pour Grafana"
  type        = string
  sensitive   = true
}

variable "prometheus_storage_size" {
  description = "Taille du stockage Prometheus"
  type        = string
  default     = "10Gi"
}
