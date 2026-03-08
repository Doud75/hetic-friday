include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../terraform/modules/monitoring-k8s"
}

dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    cluster_name                       = "mock-cluster"
    cluster_endpoint                   = "https://mock-endpoint.eks.amazonaws.com"
    cluster_certificate_authority_data = "bW9jaw=="
  }
}

locals {
  root_vars   = read_terragrunt_config(find_in_parent_folders("root.hcl"))
  secret_vars = read_terragrunt_config(find_in_parent_folders("secrets.hcl", "${get_terragrunt_dir()}/secrets.hcl"))
}

inputs = {
  environment = "dev"
  region      = local.root_vars.locals.region

  cluster_name                       = dependency.eks.outputs.cluster_name
  cluster_endpoint                   = dependency.eks.outputs.cluster_endpoint
  cluster_certificate_authority_data = dependency.eks.outputs.cluster_certificate_authority_data

  grafana_admin_password  = local.secret_vars.inputs.grafana_admin_password
  prometheus_storage_size = "10Gi"
}
