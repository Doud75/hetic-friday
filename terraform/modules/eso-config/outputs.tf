output "cluster_secret_store_name" {
  description = "Nom du ClusterSecretStore ESO"
  value       = kubernetes_manifest.cluster_secret_store.manifest.metadata.name
}