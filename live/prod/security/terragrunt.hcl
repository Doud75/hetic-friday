include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../terraform/modules/security"
}

locals {
  ip_config = read_terragrunt_config(find_in_parent_folders("ip.hcl", "${get_terragrunt_dir()}/ip.hcl"))
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

  ip_publique = local.ip_config.inputs.ip_publique
}