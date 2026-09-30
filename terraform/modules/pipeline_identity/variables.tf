variable "create_oidc_provider" {
  description = "Cria o provider OIDC do GitHub. Use false se a conta já tiver um (ele é único por conta)"
  type        = bool
  default     = true
}

variable "ecr_repository_arn" {
  description = "ARN do repositório ECR onde o pipeline publica a imagem"
  type        = string
}

variable "github_branch" {
  description = "Branch autorizada a assumir a role"
  type        = string
  default     = "main"
}

variable "github_repository" {
  description = "Repositório no formato owner/nome autorizado a assumir a role"
  type        = string

  validation {
    condition     = can(regex("^[^/]+/[^/]+$", var.github_repository))
    error_message = "Use o formato owner/repositorio (ex: robson-devops/devops-03-eks-gitops)."
  }
}

variable "name_prefix" {
  description = "Prefixo aplicado ao nome dos recursos criados pelo módulo"
  type        = string
}
