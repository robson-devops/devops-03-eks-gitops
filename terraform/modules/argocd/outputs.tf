output "namespace" {
  description = "Namespace do Argo CD"
  value       = helm_release.argocd.namespace
}
