include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../terraform/modules/finops"
}

locals {
  secrets     = read_terragrunt_config(find_in_parent_folders("secrets.hcl"))
  alert_email = local.secrets.inputs.alert_email
}

inputs = {
  project_name         = "hetic_friday_g2"
  environment          = "prod"
  monthly_budget_limit = "600"
  eks_budget_limit     = "250"
  ec2_budget_limit     = "250"
  rds_budget_limit     = "50"
  alert_emails         = [local.alert_email]
}
