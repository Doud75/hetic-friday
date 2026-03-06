output "grafana_service_name" {
  description = "Nom du Service Kubernetes de Grafana"
  value       = "kube-prometheus-stack-grafana"
}

output "prometheus_service_name" {
  description = "Nom du Service Kubernetes de Prometheus"
  value       = "kube-prometheus-stack-prometheus"
}

output "namespace" {
  description = "Namespace Kubernetes du monitoring"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}
