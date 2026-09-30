locals {
  oidc_url = "token.actions.githubusercontent.com"

  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn

  repository_owner = split("/", var.github_repository)[0]
  repository_name  = split("/", var.github_repository)[1]

  # Formato clássico e formato com IDs imutáveis do "sub" emitido pelo GitHub.
  subject_pattern = [
    "repo:${var.github_repository}:ref:refs/heads/${var.github_branch}",
    "repo:${local.repository_owner}@*/${local.repository_name}@*:ref:refs/heads/${var.github_branch}",
  ]
}
