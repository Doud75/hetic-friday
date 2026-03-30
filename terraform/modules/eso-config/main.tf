provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.region]
  }
}

resource "kubernetes_manifest" "cluster_secret_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = "aws-secrets-manager"
    }
    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = var.region
          auth = {
            jwt = {
              serviceAccountRef = {
                name      = "external-secrets"
                namespace = var.eso_namespace
              }
            }
          }
        }
      }
    }
  }
}


resource "kubernetes_manifest" "rds_external_secret" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "rds-credentials"
      namespace = "default"
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = kubernetes_manifest.cluster_secret_store.manifest.metadata.name
        kind = "ClusterSecretStore"
      }
      target = {
        name = "rds-credentials"
      }
      dataFrom = [{
        extract = {
          key = "${var.project_name}-${var.environment}-rds-credentials"
        }
      }]
    }
  }

  depends_on = [kubernetes_manifest.cluster_secret_store]
}