variable "project_name" {
  description = "Nom du projet"
  type        = string
}

variable "environment" {
  description = "Environnement (dev, prod)"
  type        = string
}

variable "region" {
  description = "Région AWS"
  type        = string
  default     = "eu-central-1"
}

variable "vpc_id" {
  description = "ID du VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs des subnets privés pour les nodes EKS"
  type        = list(string)
}

variable "cluster_version" {
  description = "Version Kubernetes"
  type        = string
  default     = "1.34"
}



variable "map_users" {
  description = "Liste des utilisateurs à mapper avec EKS"
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}
