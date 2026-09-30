locals {
  # EKS cria este log group sozinho, sem retenção, se ele não existir.
  log_group_name = "/aws/eks/${var.cluster_name}/cluster"
}
