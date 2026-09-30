# IRSA: só a service account do controller assume esta role.
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:sub"
      values   = ["system:serviceaccount:${local.namespace}:${local.service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "main" {
  name               = "${var.cluster_name}-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# Policy oficial publicada com o controller. Atualizar junto com chart_version.
resource "aws_iam_policy" "main" {
  name   = "${var.cluster_name}-load-balancer-controller"
  policy = file("${path.module}/iam_policy.json")
}

resource "aws_iam_role_policy_attachment" "main" {
  role       = aws_iam_role.main.name
  policy_arn = aws_iam_policy.main.arn
}

resource "helm_release" "main" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.chart_version
  namespace  = local.namespace
  wait       = true

  values = [yamlencode({
    clusterName = var.cluster_name
    # Região e VPC explícitas: o controller não depende do IMDS do node.
    region = var.aws_region
    vpcId  = var.vpc_id

    # Não converter Services LoadBalancer em NLB; o projeto usa só Ingress.
    enableServiceMutatorWebhook = false

    serviceAccount = {
      create = true
      name   = local.service_account_name
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.main.arn
      }
    }
  })]

  depends_on = [aws_iam_role_policy_attachment.main]
}
