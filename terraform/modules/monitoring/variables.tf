variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "hetic-friday-g2"
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
  default     = "dev"
}

variable "nat_gateway_ids" {
  description = "List of NAT Gateway IDs to monitor"
  type        = list(string)
}

variable "alert_email" {
  description = "Email address to receive CloudWatch alarm notifications"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

