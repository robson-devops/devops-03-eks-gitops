variable "aws_region" {
  description = "Região AWS do cluster"
  type        = string
}

variable "chart_version" {
  description = "Versão do chart aws-load-balancer-controller. A iam_policy.json precisa ser a da mesma versão"
  type        = string
  default     = "3.5.0"
}

variable "cluster_name" {
  description = "Nome do cluster EKS"
  type        = string
}

variable "oidc_issuer_url" {
  description = "URL do emissor OIDC do cluster"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN do provider OIDC do cluster"
  type        = string
}

variable "vpc_id" {
  description = "ID da VPC do cluster"
  type        = string
}
