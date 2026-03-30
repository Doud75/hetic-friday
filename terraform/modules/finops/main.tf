# ──────────────────────────────────────────────
# AWS BUDGETS — Suivi et alertes de coûts
# ──────────────────────────────────────────────

resource "aws_budgets_budget" "monthly_total" {
  name         = "${var.project_name}-${var.environment}-monthly-budget"
  budget_type  = "COST"
  limit_amount = var.monthly_budget_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Alerte à 50% du budget
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
  }

  # Alerte à 80% du budget
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
  }

  # Alerte à 100% du budget
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
  }

  # Alerte de prévision à 100% (forecast)
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.alert_emails
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-monthly-budget"
    Environment = var.environment
    managed-by  = "terraform"
  }
}

# ──────────────────────────────────────────────
# BUDGET PAR SERVICE — EKS, RDS, EC2
# Pour identifier quel service consomme le plus
# ──────────────────────────────────────────────

resource "aws_budgets_budget" "eks_budget" {
  name         = "${var.project_name}-${var.environment}-eks-budget"
  budget_type  = "COST"
  limit_amount = var.eks_budget_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "Service"
    values = ["Amazon Elastic Kubernetes Service"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-eks-budget"
    Environment = var.environment
    managed-by  = "terraform"
  }
}

resource "aws_budgets_budget" "ec2_budget" {
  name         = "${var.project_name}-${var.environment}-ec2-budget"
  budget_type  = "COST"
  limit_amount = var.ec2_budget_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "Service"
    values = ["Amazon Elastic Compute Cloud - Compute"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-ec2-budget"
    Environment = var.environment
    managed-by  = "terraform"
  }
}

resource "aws_budgets_budget" "rds_budget" {
  name         = "${var.project_name}-${var.environment}-rds-budget"
  budget_type  = "COST"
  limit_amount = var.rds_budget_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "Service"
    values = ["Amazon Relational Database Service"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-rds-budget"
    Environment = var.environment
    managed-by  = "terraform"
  }
}
