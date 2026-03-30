include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../terraform/modules/alb"
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id            = "vpc-mock-12345"
    public_subnet_ids = ["subnet-mock-1", "subnet-mock-2", "subnet-mock-3"]
  }
}

dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    cluster_name                       = "mock-cluster"
    cluster_endpoint                   = "https://mock-endpoint.eks.amazonaws.com"
    cluster_certificate_authority_data = "bW9jaw=="
    cluster_security_group_id          = "sg-mock-12345"
  }
}

inputs = {
  project_name = "hetic-friday"
  environment  = "prod"

  vpc_id                    = dependency.vpc.outputs.vpc_id
  public_subnet_ids         = dependency.vpc.outputs.public_subnet_ids
  cluster_security_group_id = dependency.eks.outputs.cluster_security_group_id

  # EKS cluster info — pour le tag eks:eks-cluster-name et le provider K8s
  cluster_name                       = dependency.eks.outputs.cluster_name
  cluster_endpoint                   = dependency.eks.outputs.cluster_endpoint
  cluster_certificate_authority_data = dependency.eks.outputs.cluster_certificate_authority_data
}
