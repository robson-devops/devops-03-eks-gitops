locals {
  oidc_issuer_host = replace(var.oidc_issuer_url, "https://", "")
  sns_kms_alias    = "alias/aws/sns"
}
