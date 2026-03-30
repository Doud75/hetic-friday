include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../terraform/modules/ecr"
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id                  = "vpc-mock-12345"
    vpc_cidr                = "10.0.0.0/16"
    private_subnet_ids      = ["subnet-mock-1", "subnet-mock-2", "subnet-mock-3"]
    private_route_table_ids = ["rtb-mock-1", "rtb-mock-2", "rtb-mock-3"]
  }
}

inputs = {
  environment = "prod"

  vpc_id                  = dependency.vpc.outputs.vpc_id
  vpc_cidr                = dependency.vpc.outputs.vpc_cidr
  private_subnet_ids      = dependency.vpc.outputs.private_subnet_ids
  private_route_table_ids = dependency.vpc.outputs.private_route_table_ids
}