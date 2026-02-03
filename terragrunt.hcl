locals {
  project_name = "hetic_friday_g2"
  region       = "eu-central-1"
}

remote_state {
  backend = "s3"
  
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  
  config = {
    bucket         = "hetic-friday-g2-terraform-state"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.region
    encrypt        = true
    dynamodb_table = "hetic-friday-g2-terraform-locks"
    
    s3_bucket_tags = {
      Name        = "${local.project_name}-terraform-state"
      Project     = local.project_name
      ManagedBy   = "Terragrunt"
      Environment = "shared"
    }
    
    dynamodb_table_tags = {
      Name        = "${local.project_name}-terraform-locks"
      Project     = local.project_name
      ManagedBy   = "Terragrunt"
      Environment = "shared"
    }
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = var.region
  
  default_tags {
    tags = {
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Environment = var.environment
    }
  }
}
EOF
}

inputs = {
  project_name = local.project_name
  region       = local.region
}
