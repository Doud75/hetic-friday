variable "project_name" {
  description = "Nom du projet"
  type        = string
}

variable "environment" {
  description = "Environnement (dev, prod)"
  type        = string
}

variable "monthly_budget_limit" {
  description = "Limite mensuelle totale en USD"
  type        = string
  default     = "500"
}

variable "eks_budget_limit" {
  description = "Limite mensuelle EKS en USD"
  type        = string
  default     = "200"
}

variable "ec2_budget_limit" {
  description = "Limite mensuelle EC2 en USD"
  type        = string
  default     = "200"
}

variable "rds_budget_limit" {
  description = "Limite mensuelle RDS en USD"
  type        = string
  default     = "50"
}

variable "alert_emails" {
  description = "Adresses email pour les alertes budget"
  type        = list(string)
}
