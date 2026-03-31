output "chaos_mesh_namespace" {
  description = "Namespace de Chaos Mesh"
  value       = kubernetes_namespace.chaos_mesh.metadata[0].name
}

output "dashboard_service" {
  description = "Nom du service dashboard Chaos Mesh (port-forward vers ce service)"
  value       = "chaos-dashboard"
}
