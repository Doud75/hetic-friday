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

variable "system_node_desired_size" {
  description = "Nombre désiré de nodes système"
  type        = number
  default     = 2
}

variable "system_node_min_size" {
  description = "Nombre minimum de nodes système"
  type        = number
  default     = 2
}

variable "system_node_max_size" {
  description = "Nombre maximum de nodes système"
  type        = number
  default     = 3
}

variable "system_instance_types" {
  description = "Types d'instances pour les nodes système"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "app_node_desired_size" {
  description = "Nombre désiré de nodes applicatifs"
  type        = number
  default     = 2
}

variable "app_node_min_size" {
  description = "Nombre minimum de nodes applicatifs"
  type        = number
  default     = 2
}

variable "app_node_max_size" {
  description = "Nombre maximum de nodes applicatifs"
  type        = number
  default     = 10
}

variable "app_instance_types" {
  description = "Types d'instances pour les nodes applicatifs"
  type        = list(string)
  default     = ["t3.large"]
}

variable "enable_spot_instances" {
  description = "Utiliser des Spot instances pour les nodes applicatifs"
  type        = bool
  default     = true
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
