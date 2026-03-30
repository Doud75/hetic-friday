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
# Prêtes à être appliquées pendant les tests
# ──────────────────────────────────────────────

# Expérience 1 : Tuer un pod aléatoirement (PodChaos)
resource "kubernetes_manifest" "pod_kill_experiment" {
  manifest = {
    apiVersion = "chaos-mesh.org/v1alpha1"
    kind       = "PodChaos"
    metadata = {
      name      = "pod-kill-random"
      namespace = kubernetes_namespace.chaos_mesh.metadata[0].name
      annotations = {
        description = "Tue un pod aléatoire dans le namespace cible pour tester le self-healing Kubernetes"
      }
    }
    spec = {
      action = "pod-kill"
      mode   = "one"
      selector = {
        namespaces = [var.target_namespace]
      }
      duration = "30s"
    }
  }

  depends_on = [helm_release.chaos_mesh]
}

# Expérience 2 : Injection de latence réseau (NetworkChaos)
resource "kubernetes_manifest" "network_delay_experiment" {
  manifest = {
    apiVersion = "chaos-mesh.org/v1alpha1"
    kind       = "NetworkChaos"
    metadata = {
      name      = "network-delay-200ms"
      namespace = kubernetes_namespace.chaos_mesh.metadata[0].name
      annotations = {
        description = "Ajoute 200ms de latence réseau pour simuler une dégradation de performance inter-services"
      }
    }
    spec = {
      action = "delay"
      mode   = "all"
      selector = {
        namespaces = [var.target_namespace]
        labelSelectors = {
          app = "frontend"
        }
      }
      delay = {
        latency     = "200ms"
        jitter      = "50ms"
        correlation = "50"
      }
      duration = "2m"
    }
  }

  depends_on = [helm_release.chaos_mesh]
}

# Expérience 3 : Stress CPU (StressChaos)
resource "kubernetes_manifest" "cpu_stress_experiment" {
  manifest = {
    apiVersion = "chaos-mesh.org/v1alpha1"
    kind       = "StressChaos"
    metadata = {
      name      = "cpu-stress-frontend"
      namespace = kubernetes_namespace.chaos_mesh.metadata[0].name
      annotations = {
        description = "Stress CPU sur le frontend pour vérifier que l'HPA réagit correctement"
      }
    }
    spec = {
      mode = "one"
      selector = {
        namespaces = [var.target_namespace]
        labelSelectors = {
          app = "frontend"
        }
      }
      stressors = {
        cpu = {
          workers = 2
          load    = 80
        }
      }
      duration = "3m"
    }
  }

  depends_on = [helm_release.chaos_mesh]
}
