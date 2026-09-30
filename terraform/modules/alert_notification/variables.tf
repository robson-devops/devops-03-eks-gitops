variable "alert_email" {
  description = "E-mail que recebe os alertas. Vazio cria o tópico sem assinatura"
  type        = string
  default     = ""

  validation {
    condition     = var.alert_email == "" || can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email))
    error_message = "Informe um e-mail válido ou deixe vazio."
  }
}

variable "name_prefix" {
  description = "Prefixo do tópico SNS e da role"
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

variable "service_account_name" {
  description = "Service account do Alertmanager, criada pelo kube-prometheus-stack"
  type        = string
  default     = "monitoring-kube-prometheus-alertmanager"
}

variable "service_account_namespace" {
  description = "Namespace do Alertmanager"
  type        = string
  default     = "monitoring"
}
