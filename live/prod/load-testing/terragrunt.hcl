include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../../../terraform/modules/load-testing"
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id            = "vpc-mock-12345"
    public_subnet_ids = ["subnet-mock-1", "subnet-mock-2"]
  }
}

locals {
  secret_vars = read_terragrunt_config(find_in_parent_folders("secrets.hcl", "${get_terragrunt_dir()}/secrets.hcl"))
}

inputs = {
  environment = "prod"

  vpc_id           = dependency.vpc.outputs.vpc_id
  public_subnet_id = dependency.vpc.outputs.public_subnet_ids[0]

  instance_type = "t4g.medium"

  # Nom du key pair AWS existant (aws ec2 describe-key-pairs pour lister)
  key_pair_name = "k6-test-key"

  # Restreindre SSH à votre IP publique
  allowed_ssh_cidrs = [local.secret_vars.inputs.ip_publique]

  # URL cible du load balancer frontend
  base_url = "http://hetic-friday-prod-alb-1663745015.eu-central-1.elb.amazonaws.com"
}
