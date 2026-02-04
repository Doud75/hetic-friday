variable "project_name" {
  description = "Nom du projet (utilisé pour le tagging)"
  type        = string
}

variable "region" {
  description = "Région AWS"
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

variable "vpc_cidr" {
  description = "CIDR block pour le VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr doit être un CIDR valide."
  }
}

variable "availability_zones" {
  description = "Liste des availability zones à utiliser"
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]

  validation {
    condition     = length(var.availability_zones) == 3
    error_message = "Exactement 3 availability zones sont requises."
  }
}

variable "enable_nat_gateway_per_az" {
  description = "Créer un NAT Gateway par AZ (true) ou un seul (false)"
  type        = bool
  default     = false
}

variable "enable_dns_hostnames" {
  description = "Activer les hostnames DNS dans le VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Activer le support DNS dans le VPC"
  type        = bool
  default     = true
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks pour les subnets publics (Public Layer 10.0.0.0/20)"
  type        = list(string)
  default     = ["10.0.0.0/22", "10.0.4.0/22", "10.0.8.0/22"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks pour les subnets privés (Private Layer 10.0.16.0/20)"
  type        = list(string)
  default     = ["10.0.16.0/22", "10.0.20.0/22", "10.0.24.0/22"]
}

variable "data_subnet_cidrs" {
  description = "CIDR blocks pour les subnets data (Data Layer 10.0.32.0/21)"
  type        = list(string)
  default     = ["10.0.32.0/24", "10.0.33.0/24", "10.0.34.0/24"]
}
