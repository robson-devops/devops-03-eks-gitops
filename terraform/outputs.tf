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
