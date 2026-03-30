output "productcatalogservice_repository_url" {
  description = "URL du repository ECR pour productcatalogservice"
  value       = aws_ecr_repository.productcatalogservice.repository_url
}

output "registry_id" {
  description = "ID du registry ECR (account ID AWS)"
  value       = aws_ecr_repository.productcatalogservice.registry_id
}

output "ecr_api_endpoint_id" {
  description = "ID du VPC Endpoint pour ecr.api"
  value       = aws_vpc_endpoint.ecr_api.id
}

output "ecr_dkr_endpoint_id" {
  description = "ID du VPC Endpoint pour ecr.dkr"
  value       = aws_vpc_endpoint.ecr_dkr.id
}

output "s3_endpoint_id" {
  description = "ID du VPC Gateway Endpoint pour S3"
  value       = aws_vpc_endpoint.s3.id
}