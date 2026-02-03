include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../terraform/modules/networking"
}

inputs = {
  environment = "dev"
  
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  
  enable_nat_gateway_per_az = false
  
  public_subnet_cidrs  = ["10.0.0.0/22", "10.0.4.0/22", "10.0.8.0/22"]
  private_subnet_cidrs = ["10.0.16.0/22", "10.0.20.0/22", "10.0.24.0/22"]
  data_subnet_cidrs    = ["10.0.32.0/24", "10.0.33.0/24", "10.0.34.0/24"]
}
