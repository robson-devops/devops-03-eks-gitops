output "nat_gateway_public_ip" {
  description = "IP público de saída das subnets privadas"
  value       = aws_eip.nat.public_ip
}

output "private_subnet_id" {
  description = "IDs das subnets privadas, para os nodes do EKS"
  value       = [for subnet in aws_subnet.private : subnet.id]
}

output "public_subnet_id" {
  description = "IDs das subnets públicas, para o ALB e o NAT Gateway"
  value       = [for subnet in aws_subnet.public : subnet.id]
}

output "vpc_cidr_block" {
  description = "CIDR block da VPC, para regras de security group internas"
  value       = aws_vpc.main.cidr_block
}

output "vpc_id" {
  description = "ID da VPC criada"
  value       = aws_vpc.main.id
}
