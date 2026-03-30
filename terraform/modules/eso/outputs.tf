output "eso_role_arn" {
  description = "ARN du rôle IAM IRSA pour External Secrets Operator"
  value       = aws_iam_role.eso.arn
}

output "eso_namespace" {
  description = "Namespace Kubernetes où tourne External Secrets Operator"
  value       = kubernetes_namespace.external_secrets.metadata[0].name
}