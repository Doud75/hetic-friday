variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "vpc_id" {
  description = "ID du VPC dans lequel créer les VPC Endpoints"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block du VPC, utilisé pour la règle ingress du Security Group des endpoints"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs des subnets privés pour les interface endpoints ECR"
  type        = list(string)
}

variable "private_route_table_ids" {
  description = "IDs des route tables privées pour l'association du gateway endpoint S3"
  type        = list(string)
}

variable "image_retention_count" {
  description = "Number of tagged images to retain per repository"
  type        = number
  default     = 10
}