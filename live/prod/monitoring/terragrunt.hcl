include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  secrets = yamldecode(file("${get_terragrunt_dir()}/../secrets.yaml"))
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
  environment = "prod"
  
  nat_gateway_ids = dependency.networking.outputs.nat_gateway_ids
  alert_email     = local.secrets.alert_email
}
