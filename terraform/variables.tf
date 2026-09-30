variable "aws_region" {
  description = "Região AWS onde a infraestrutura será provisionada"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Ambiente ao qual os recursos pertencem"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "O ambiente deve ser dev, staging ou prod."
  }
}

variable "project_name" {
  description = "Nome do projeto, usado como prefixo dos recursos e nas tags"
  type        = string
  default     = "devops-03"
}

variable "vpc_cidr" {
  description = "CIDR block da VPC. Precisa comportar as quatro subnets /20 derivadas dele"
  type        = string
  default     = "10.40.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && tonumber(split("/", var.vpc_cidr)[1]) <= 16
    error_message = "vpc_cidr deve ser um CIDR válido com máscara /16 ou maior (ex: 10.40.0.0/16)."
  }
}

variable "cluster_version" {
  description = "Versão do Kubernetes do cluster EKS"
  type        = string
  default     = "1.35"
}

variable "operator_cidr" {
  description = "CIDR de quem opera o cluster (ex: 203.0.113.10/32), único autorizado no endpoint público da API"
  type        = list(string)
}

variable "gitops_repository_url" {
  description = "Repositório lido pelo Argo CD. Em um fork, troque pela URL do seu repositório"
  type        = string
  default     = "https://github.com/robson-devops/devops-03-eks-gitops.git"
}

variable "alert_email" {
  description = "E-mail que recebe os alertas da aplicação via SNS. Vazio desativa o envio"
  type        = string
  default     = ""
}

variable "github_repository" {
  description = "Repositório (owner/nome) cujo pipeline publica imagens no ECR. Em um fork, troque pelo seu"
  type        = string
  default     = "robson-devops/devops-03-eks-gitops"
}

variable "create_oidc_provider" {
  description = "Cria o provider OIDC do GitHub, apagado no destroy. Use false se a conta já tiver um"
  type        = bool
  default     = true
}
