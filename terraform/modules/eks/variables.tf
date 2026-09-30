variable "cluster_name" {
  description = "Nome do cluster EKS, também usado como prefixo das roles"
  type        = string
}

variable "cluster_version" {
  description = "Versão do Kubernetes do control plane"
  type        = string

  validation {
    condition     = can(regex("^1\\.[0-9]{2}$", var.cluster_version))
    error_message = "Use o formato 1.XX (ex: 1.35)."
  }
}

variable "endpoint_public_access_cidr" {
  description = "CIDRs autorizados a acessar o endpoint público da API do Kubernetes"
  type        = list(string)

  validation {
    condition     = length(var.endpoint_public_access_cidr) > 0 && alltrue([for cidr in var.endpoint_public_access_cidr : can(cidrhost(cidr, 0)) && cidr != "0.0.0.0/0"])
    error_message = "Informe ao menos um CIDR válido, e nunca 0.0.0.0/0."
  }
}

variable "log_retention_day" {
  description = "Dias de retenção dos logs do control plane no CloudWatch"
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365], var.log_retention_day)
    error_message = "Use um dos valores de retenção aceitos pelo CloudWatch Logs (1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180 ou 365)."
  }
}

variable "node_desired_size" {
  description = "Quantidade de nodes desejada no node group"
  type        = number
  default     = 2
}

variable "node_disk_size_gb" {
  description = "Tamanho do disco de cada node, em GB"
  type        = number
  default     = 20
}

variable "node_instance_type" {
  description = "Tipo de instância dos nodes"
  type        = string
  default     = "t3.medium"
}

variable "node_max_size" {
  description = "Quantidade máxima de nodes no node group"
  type        = number
  default     = 3
}

variable "node_min_size" {
  description = "Quantidade mínima de nodes no node group"
  type        = number
  default     = 2

  validation {
    condition     = var.node_min_size >= 1
    error_message = "O node group precisa de ao menos 1 node."
  }
}

variable "subnet_id" {
  description = "IDs das subnets privadas onde ficam o control plane (ENIs) e os nodes"
  type        = list(string)

  validation {
    condition     = length(var.subnet_id) >= 2
    error_message = "O EKS exige subnets em ao menos duas AZs."
  }
}
