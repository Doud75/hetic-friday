variable "region" {
  description = "Région AWS"
  type        = string
}

variable "project_name" {
  description = "Nom du projet"
  type        = string
}

variable "environment" {
  description = "Environnement (dev, prod)"
  type        = string
}

variable "ip_publique" {
  description = "IP Publique autorisée à accéder à l'instance"
  type        = string
  default     = "x.x.x.x/32"
  
}

variable "vpc_id" {
  description = "ID du VPC"
  type        = string
}