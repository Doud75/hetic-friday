variable "environment" {
  description = "Nom de l'environnement"
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Nom du projet"
  type        = string
}

variable "region" {
  description = "Région AWS"
  type        = string
}

variable "vpc_id" {
  description = "ID du VPC"
  type        = string
}

variable "public_subnet_id" {
  description = "ID du subnet public où déployer l'instance"
  type        = string
}

variable "instance_type" {
  description = "Type d'instance EC2 pour le load testing (ARM64, famille t4g recommandée)"
  type        = string
  default     = "t4g.medium"
}

variable "key_pair_name" {
  description = "Nom du key pair AWS existant à utiliser pour SSH"
  type        = string
}

variable "allowed_ssh_cidrs" {
  description = "Liste des CIDR autorisés à se connecter en SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "base_url" {
  description = "URL cible pour les tests de charge k6"
  type        = string
}

variable "k6_stages" {
  description = "Stages k6 au format JSON (sera injecté dans le script)"
  type        = string
  default     = ""
}
