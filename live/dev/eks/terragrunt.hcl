include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../terraform/modules/eks"
}

dependency "vpc" {
  config_path = "../vpc"
  
  mock_outputs = {
    vpc_id             = "vpc-mock-12345678"
    private_subnet_ids = ["subnet-mock-1", "subnet-mock-2", "subnet-mock-3"]
  }
}

locals {
  secret_vars = read_terragrunt_config(find_in_parent_folders("secrets.hcl", "${get_terragrunt_dir()}/secrets.hcl"))
}

inputs = {
  project_name       = "hetic_friday_g2"
  environment        = "dev"
  
  vpc_id             = dependency.vpc.outputs.vpc_id
  private_subnet_ids = dependency.vpc.outputs.private_subnet_ids

  cluster_version = "1.34"

  map_users = local.secret_vars.inputs.map_users
}
