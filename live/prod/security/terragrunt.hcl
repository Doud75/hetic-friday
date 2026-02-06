include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  secret_vars = read_terragrunt_config(find_in_parent_folders("secrets.hcl", "${get_terragrunt_dir()}/secrets.hcl"))
}

terraform {
  source = "../../../terraform/modules/security"
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id = "vpc-mock-12345678"
  }
}

inputs = {
  environment = "prod"
  
  vpc_id = dependency.vpc.outputs.vpc_id

  ip_publique = local.secret_vars.inputs.ip_publique
}