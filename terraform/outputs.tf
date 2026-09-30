output "nat_gateway_public_ip" {
  description = "IP público de saída das subnets privadas (NAT Gateway)"
  value       = module.network.nat_gateway_public_ip
}

output "private_subnet_id" {
  description = "IDs das subnets privadas, onde ficam os nodes do EKS"
  value       = module.network.private_subnet_id
}

output "public_subnet_id" {
  description = "IDs das subnets públicas, onde ficam o ALB e o NAT Gateway"
  value       = module.network.public_subnet_id
}

output "vpc_id" {
  description = "ID da VPC do projeto"
  value       = module.network.vpc_id
}

output "cluster_name" {
  description = "Nome do cluster EKS"
  value       = module.eks.cluster_name
}

output "kubeconfig_command" {
  description = "Comando para configurar o kubectl"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}

output "argocd_admin_password_command" {
  description = "Comando para ler a senha inicial do usuário admin do Argo CD"
  value       = "kubectl -n ${module.argocd.namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

output "ecr_repository_url" {
  description = "URL do repositório ECR da aplicação"
  value       = module.ecr.repository_url
}

output "alertmanager_role_arn" {
  description = "Role IRSA do Alertmanager"
  value       = module.alert_notification.role_arn
}

output "alert_topic_arn" {
  description = "Tópico SNS dos alertas"
  value       = module.alert_notification.topic_arn
}

output "pipeline_role_arn" {
  description = "Role do GitHub Actions. Cadastre como secret AWS_ROLE_ARN no repositório"
  value       = module.pipeline_identity.role_arn
}
