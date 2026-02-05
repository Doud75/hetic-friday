output "cluster_id" {
  description = "ID du cluster EKS"
  value       = aws_eks_cluster.main.id
}

output "cluster_name" {
  description = "Nom du cluster EKS"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "Endpoint du cluster EKS"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Certificat CA du cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "ID du security group du cluster"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "cluster_oidc_issuer_url" {
  description = "URL de l'OIDC provider (pour IRSA)"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}
