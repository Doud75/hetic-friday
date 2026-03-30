include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../terraform/modules/eso"
}

dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    cluster_name                       = "mock-cluster"
    cluster_endpoint                   = "https://mock-endpoint.eks.amazonaws.com"
    cluster_certificate_authority_data = "bW9jaw=="
    oidc_provider_arn                  = "arn:aws:iam::123456789012:oidc-provider/mock"
    cluster_oidc_issuer_url            = "https://oidc.eks.eu-central-1.amazonaws.com/id/mock"
  }
}

dependency "rds" {
  config_path = "../rds"

  mock_outputs = {
    secret_arn = "arn:aws:secretsmanager:eu-central-1:123456789012:secret:mock-rds-credentials"
  }
}

inputs = {
  environment = "prod"

  cluster_name                       = dependency.eks.outputs.cluster_name
  cluster_endpoint                   = dependency.eks.outputs.cluster_endpoint
  cluster_certificate_authority_data = dependency.eks.outputs.cluster_certificate_authority_data
  oidc_provider_arn                  = dependency.eks.outputs.oidc_provider_arn
  oidc_issuer_url                    = dependency.eks.outputs.cluster_oidc_issuer_url

  rds_secret_arn = dependency.rds.outputs.secret_arn
}