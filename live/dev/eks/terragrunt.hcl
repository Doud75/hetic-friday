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

inputs = {
  project_name       = "hetic_friday_g2"
  environment        = "dev"
  
  vpc_id             = dependency.vpc.outputs.vpc_id
  private_subnet_ids = dependency.vpc.outputs.private_subnet_ids

  cluster_version = "1.34"

  system_node_desired_size = 2
  system_node_min_size     = 2
  system_node_max_size     = 3
  system_instance_types    = ["t3.small"]

  app_node_desired_size = 2
  app_node_min_size     = 2
  app_node_max_size     = 10
  app_instance_types    = ["t3.small"]

  enable_spot_instances = true
}
