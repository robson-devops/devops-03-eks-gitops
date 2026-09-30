variable "argocd_apps_chart_version" {
  description = "Versão do chart argocd-apps, que cria a Application raiz"
  type        = string
  default     = "2.0.6"
}

variable "argocd_chart_version" {
  description = "Versão do chart argo-cd"
  type        = string
  default     = "10.9.4"
}

variable "namespace" {
  description = "Namespace onde o Argo CD é instalado"
  type        = string
  default     = "argocd"
}

variable "repository_url" {
  description = "URL HTTPS do repositório Git lido pelo Argo CD"
  type        = string

  validation {
    condition     = startswith(var.repository_url, "https://")
    error_message = "Use a URL HTTPS do repositório (ex: https://github.com/dono/repositorio.git)."
  }
}

variable "root_path" {
  description = "Pasta do repositório com as Applications filhas"
  type        = string
  default     = "gitops/apps"
}

variable "target_revision" {
  description = "Branch, tag ou commit que o Argo CD acompanha"
  type        = string
  default     = "main"
}
