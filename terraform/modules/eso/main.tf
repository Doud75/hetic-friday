# ──────────────────────────────────────────────
# PROVIDERS — connexion au cluster EKS
# ──────────────────────────────────────────────

provider "helm" {
  kubernetes {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.region]
    }
  }
}

provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.region]
  }
}

# ──────────────────────────────────────────────
# IAM — rôle IRSA pour External Secrets Operator
# ──────────────────────────────────────────────

locals {
  oidc_issuer = trimprefix(var.oidc_issuer_url, "https://")
}

resource "aws_iam_role" "eso" {
  name = "${var.project_name}-${var.environment}-eso-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_issuer}:sub" = "system:serviceaccount:external-secrets:external-secrets"
          "${local.oidc_issuer}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-eso-role"
    Environment = var.environment
  }
}

resource "aws_iam_policy" "eso_secrets" {
  name        = "${var.project_name}-${var.environment}-eso-secrets-policy"
  description = "Permet à External Secrets Operator de lire les secrets RDS depuis Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      Resource = var.rds_secret_arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eso_secrets" {
  role       = aws_iam_role.eso.name
  policy_arn = aws_iam_policy.eso_secrets.arn
}

# ──────────────────────────────────────────────
# NAMESPACE
# ──────────────────────────────────────────────

resource "kubernetes_namespace" "external_secrets" {
  metadata {
    name = "external-secrets"

    labels = {
      name        = "external-secrets"
      environment = var.environment
      managed-by  = "terraform"
    }
  }
}

# ──────────────────────────────────────────────
# HELM — External Secrets Operator
# ClusterSecretStore et ExternalSecret sont dans le module eso-config
# qui dépend de celui-ci, garantissant que les CRDs existent au plan.
# ──────────────────────────────────────────────

resource "helm_release" "eso" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  namespace  = kubernetes_namespace.external_secrets.metadata[0].name
  version    = "0.10.7"

  timeout = 300
  wait    = true

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.eso.arn
  }

  depends_on = [
    kubernetes_namespace.external_secrets,
    aws_iam_role_policy_attachment.eso_secrets,
  ]
}
