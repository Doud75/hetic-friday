include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  secret_vars = read_terragrunt_config(find_in_parent_folders("secrets.hcl", "${get_terragrunt_dir()}/secrets.hcl"))
}

terraform {
  source = "../../../terraform/modules/monitoring"
}

dependency "networking" {
  config_path = "../networking"
  
  mock_outputs = {
    nat_gateway_ids = ["nat-0123456789abcdef0"]
  }
}

inputs = {
  environment = "dev"
  
  nat_gateway_ids = dependency.networking.outputs.nat_gateway_ids
  alert_email     = local.secrets.alert_email
}
