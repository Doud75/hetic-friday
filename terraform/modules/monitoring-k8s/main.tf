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

  # Prometheus scrape tous les ServiceMonitors/PodMonitors du cluster,
  # pas seulement ceux générés par ce chart Helm.
  # Indispensable pour monitorer les apps applicatives.
  set {
    name  = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues"
    value = "false"
  }

  set {
    name  = "prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues"
    value = "false"
  }

  set {
    name  = "prometheus.prometheusSpec.ruleSelectorNilUsesHelmValues"
    value = "false"
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


# ──────────────────────────────────────────────
# JAEGER — Tracing distribué
# Permet de suivre une requête à travers les 11 microservices
# ──────────────────────────────────────────────

resource "helm_release" "jaeger" {
  name       = "jaeger"
  repository = "https://jaegertracing.github.io/helm-charts"
  chart      = "jaeger"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "3.4.1"

  timeout = 600
  wait    = true

  # Mode all-in-one pour réduire les coûts (1 seul pod)
  set {
    name  = "provisionDataStore.cassandra"
    value = "false"
  }

  set {
    name  = "allInOne.enabled"
    value = "true"
  }

  set {
    name  = "agent.enabled"
    value = "false"
  }

  set {
    name  = "collector.enabled"
    value = "false"
  }

  set {
    name  = "query.enabled"
    value = "false"
  }

  # Stockage in-memory (suffisant pour le projet, pas de Cassandra/Elasticsearch)
  set {
    name  = "storage.type"
    value = "memory"
  }

  set {
    name  = "allInOne.extraEnv[0].name"
    value = "MEMORY_MAX_TRACES"
  }

  set {
    name  = "allInOne.extraEnv[0].value"
    value = "10000"
    type  = "string"
  }

  depends_on = [kubernetes_namespace.monitoring]
}


# ──────────────────────────────────────────────
# PROMETHEUS RULES — Alertes applicatives Black Friday
# Ces règles surveillent les métriques critiques pendant
# le test de charge et déclenchent des alertes via AlertManager.
# ──────────────────────────────────────────────

resource "kubernetes_manifest" "blackfriday_alerts" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "blackfriday-alerts"
      namespace = kubernetes_namespace.monitoring.metadata[0].name
      labels = {
        "app.kubernetes.io/part-of" = "kube-prometheus-stack"
        release                     = "kube-prometheus-stack"
      }
    }
    spec = {
      groups = [
        {
          name = "blackfriday.rules"
          rules = [
            {
              alert = "HighLatencyP95"
              expr  = "histogram_quantile(0.95, sum(rate(http_server_request_duration_seconds_bucket[5m])) by (le, service)) > 2"
              for   = "2m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "Latence P95 > 2s sur {{ $labels.service }}"
                description = "Le service {{ $labels.service }} a une latence P95 de {{ $value }}s, au-dessus du seuil de 2s requis par le cahier des charges."
              }
            },
            {
              alert = "HighErrorRate"
              expr  = "sum(rate(http_server_request_duration_seconds_count{http_status_code=~\"5..\"}[5m])) by (service) / sum(rate(http_server_request_duration_seconds_count[5m])) by (service) > 0.01"
              for   = "2m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "Taux d'erreur > 1% sur {{ $labels.service }}"
                description = "Le service {{ $labels.service }} a un taux d'erreur de {{ $value | humanizePercentage }}, au-dessus du seuil de 1% requis."
              }
            },
            {
              alert = "PodCrashLooping"
              expr  = "increase(kube_pod_container_status_restarts_total[15m]) > 3"
              for   = "5m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Pod {{ $labels.pod }} en CrashLoop"
                description = "Le pod {{ $labels.pod }} dans {{ $labels.namespace }} a redémarré {{ $value }} fois en 15 minutes."
              }
            },
            {
              alert = "HighMemoryUsage"
              expr  = "container_memory_working_set_bytes / container_spec_memory_limit_bytes > 0.9"
              for   = "5m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Mémoire > 90% sur {{ $labels.pod }}"
                description = "Le pod {{ $labels.pod }} utilise {{ $value | humanizePercentage }} de sa limite mémoire. Risque d'OOMKill."
              }
            },
            {
              alert = "HighCPUUsage"
              expr  = "sum(rate(container_cpu_usage_seconds_total[5m])) by (pod, namespace) / sum(kube_pod_container_resource_limits{resource=\"cpu\"}) by (pod, namespace) > 0.9"
              for   = "5m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "CPU > 90% sur {{ $labels.pod }}"
                description = "Le pod {{ $labels.pod }} utilise {{ $value | humanizePercentage }} de sa limite CPU. L'HPA devrait scaler."
              }
            },
            {
              alert = "HPAMaxedOut"
              expr  = "kube_horizontalpodautoscaler_status_current_replicas == kube_horizontalpodautoscaler_spec_max_replicas"
              for   = "10m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "HPA {{ $labels.horizontalpodautoscaler }} au maximum"
                description = "L'HPA {{ $labels.horizontalpodautoscaler }} a atteint son nombre maximum de replicas depuis 10 minutes. Le service ne peut plus scaler."
              }
            }
          ]
        }
      ]
    }
  }

  depends_on = [helm_release.kube_prometheus_stack]
}
