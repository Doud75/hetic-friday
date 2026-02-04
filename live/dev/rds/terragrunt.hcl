include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../terraform/modules/rds"
}

locals {
  secret_vars = read_terragrunt_config(find_in_parent_folders("secrets.hcl", "${get_terragrunt_dir()}/secrets.hcl"))
}

dependency "vpc" {
  config_path = "../vpc"
  
  mock_outputs = {
    vpc_id     = "vpc-mock-123"
    db_subnets = ["subnet-mock-db1", "subnet-mock-db2"]
  }
}

dependency "security" {
  config_path = "../security"
  mock_outputs = {
    sg_db_id = "sg-mock-db"
  }
}

inputs = {
  environment = "dev"
  
  vpc_id = dependency.vpc.outputs.vpc_id

  subnets = dependency.vpc.outputs.db_subnets

  "SG-DB" = dependency.security.outputs.sg_db_id

  db_username = local.secret_vars.inputs.db_username
  db_password = local.secret_vars.inputs.db_password
}