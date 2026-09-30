locals {
  namespace            = "kube-system"
  service_account_name = "aws-load-balancer-controller"
  oidc_issuer_host     = replace(var.oidc_issuer_url, "https://", "")
}
