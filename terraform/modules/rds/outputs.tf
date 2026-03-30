output "db_endpoint" {
  description = "Endpoint de la base RDS"
  value       = aws_db_instance.grp2dbinstance.endpoint
}
output "db_instance_id" {
  description = "ID de l'instance RDS"
  value       = aws_db_instance.grp2dbinstance.id
}

output "secret_arn" {
  description = "ARN du secret Secrets Manager contenant les credentials RDS"
  value       = aws_secretsmanager_secret.rds_credentials.arn
}