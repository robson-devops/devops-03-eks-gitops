output "cluster_endpoint" {
  description = "Endpoint da API do Kubernetes"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_name" {
  description = "Nome do cluster EKS"
  value       = aws_eks_cluster.main.name
}

output "cluster_security_group_id" {
  description = "Security group criado pelo EKS para o control plane e os nodes"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "node_role_arn" {
  description = "ARN da role dos nodes"
  value       = aws_iam_role.node.arn
}

output "oidc_issuer_url" {
  description = "URL do emissor OIDC do cluster, usada nas trust policies do IRSA"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  description = "ARN do provider OIDC do cluster, principal das trust policies do IRSA"
  value       = aws_iam_openid_connect_provider.cluster.arn
}
