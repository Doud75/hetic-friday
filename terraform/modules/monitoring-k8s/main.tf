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

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"

    labels = {
      name        = "monitoring"
      environment = var.environment
      managed-by  = "terraform"
    }
  }
}

# ──────────────────────────────────────────────
# KUBE-PROMETHEUS-STACK (Prometheus + Grafana)
# ──────────────────────────────────────────────

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "72.6.2"

  timeout = 900
  wait    = true

  # ─── GRAFANA ───

  set {
    name  = "grafana.enabled"
    value = "true"
  }

  set_sensitive {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }

  # Dev: ClusterIP (accès via port-forward → localhost:3000)
  # Prod: LoadBalancer (AWS crée un ELB → URL publique)
  set {
    name  = "grafana.service.type"
    value = var.environment == "prod" ? "LoadBalancer" : "ClusterIP"
  }

  # Dashboards Kubernetes pré-installés
  set {
    name  = "grafana.defaultDashboardsEnabled"
    value = "true"
  }

  # ─── PROMETHEUS ───

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName"
    value = "ebs-auto"
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = var.prometheus_storage_size
  }

  set {
    name  = "prometheus.prometheusSpec.retention"
    value = var.environment == "prod" ? "15d" : "7d"
  }

  # ─── NODE-EXPORTER ───
  # Toleration pour tourner aussi sur les system nodes (taint CriticalAddonsOnly)

  set {
    name  = "prometheus-node-exporter.tolerations[0].key"
    value = "CriticalAddonsOnly"
  }

  set {
    name  = "prometheus-node-exporter.tolerations[0].operator"
    value = "Exists"
  }

  set {
    name  = "prometheus-node-exporter.tolerations[0].effect"
    value = "NoSchedule"
  }

  # ─── ALERTMANAGER ───

  set {
    name  = "alertmanager.enabled"
    value = "true"
  }

  depends_on = [kubernetes_namespace.monitoring]
}
