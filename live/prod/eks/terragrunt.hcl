include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../terraform/modules/eks"
}

dependency "vpc" {
  config_path = "../vpc"
}

locals {
  secret_vars = read_terragrunt_config(find_in_parent_folders("secrets.hcl", "${get_terragrunt_dir()}/secrets.hcl"))
}

inputs = {
  project_name       = "hetic_friday_g2"
  environment        = "prod"

  vpc_id             = dependency.vpc.outputs.vpc_id
  private_subnet_ids = dependency.vpc.outputs.private_subnet_ids

  cluster_version = "1.34"

  system_node_desired_size = 3
  system_node_min_size     = 3
  system_node_max_size     = 5
  system_instance_types    = ["t3.small"]

  app_node_desired_size = 5
  app_node_min_size     = 5
  app_node_max_size     = 50
  app_instance_types    = ["t3.small"]

  enable_spot_instances = true

  map_users = local.secret_vars.inputs.map_users
}
