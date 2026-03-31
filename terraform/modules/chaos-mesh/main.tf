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
# NAMESPACE
# ──────────────────────────────────────────────

resource "kubernetes_namespace" "chaos_mesh" {
  metadata {
    name = "chaos-mesh"

    labels = {
      name        = "chaos-mesh"
      environment = var.environment
      managed-by  = "terraform"
    }
  }
}


# ──────────────────────────────────────────────
# CHAOS MESH — Ingénierie du chaos sur Kubernetes
# Permet de simuler des pannes réseau, CPU, pods, etc.
# ──────────────────────────────────────────────

resource "helm_release" "chaos_mesh" {
  name       = "chaos-mesh"
  repository = "https://charts.chaos-mesh.org"
  chart      = "chaos-mesh"
  namespace  = kubernetes_namespace.chaos_mesh.metadata[0].name
  version    = "2.7.1"

  timeout = 600
  wait    = true

  # Mode sans authentification (simplifié pour le projet pédagogique)
  set {
    name  = "dashboard.securityMode"
    value = "false"
  }

  # Dashboard activé pour visualiser les expériences
  set {
    name  = "dashboard.create"
    value = "true"
  }

  # Timezone pour le scheduling des expériences
  set {
    name  = "controllerManager.env.TZ"
    value = "Europe/Paris"
  }

  # Limiter le scope aux namespaces autorisés (pas de chaos sur monitoring!)
  set {
    name  = "controllerManager.targetNamespace"
    value = var.target_namespace
  }

  depends_on = [kubernetes_namespace.chaos_mesh]
}

# ──────────────────────────────────────────────
# EXPÉRIENCES DE CHAOS PRÉ-CONFIGURÉES
# ──────────────────────────────────────────────
# Les expériences utilisent des CRDs installées par le Helm chart Chaos Mesh.
# Elles ne peuvent PAS être gérées par Terraform dans le même apply car les CRDs
# n'existent pas encore au moment du 'plan' (erreur: "no matches for kind PodChaos").
#
# → Les expériences sont dans : app/chaos-experiments/
# → À appliquer APRÈS le premier 'terragrunt apply' de ce module :
#     kubectl apply -f app/chaos-experiments/ -n chaos-mesh

