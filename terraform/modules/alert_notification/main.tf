data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# Chave gerenciada pela AWS: a conta só a cria no primeiro uso, por isso não
# é lida por data source (falharia numa conta nova).
resource "aws_sns_topic" "main" {
  name              = "${var.name_prefix}-alerts"
  kms_master_key_id = local.sns_kms_alias
}

# Assinatura por e-mail: a AWS envia um link de confirmação a cada apply novo.
resource "aws_sns_topic_subscription" "email" {
  count = var.alert_email == "" ? 0 : 1

  topic_arn = aws_sns_topic.main.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# IRSA: só a service account do Alertmanager publica no tópico.
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
      values   = ["system:serviceaccount:${var.service_account_namespace}:${var.service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "main" {
  name               = "${var.name_prefix}-alertmanager"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "publish" {
  statement {
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.main.arn]
  }

  # Publicar em tópico cifrado exige usar a chave do SNS, identificada pelo
  # alias porque o ARN dela não existe antes do primeiro tópico.
  statement {
    effect    = "Allow"
    actions   = ["kms:GenerateDataKey*", "kms:Decrypt"]
    resources = ["arn:aws:kms:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:key/*"]

    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "kms:ResourceAliases"
      values   = [local.sns_kms_alias]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["sns.${data.aws_region.current.region}.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "publish" {
  name   = "${var.name_prefix}-alertmanager-sns"
  role   = aws_iam_role.main.id
  policy = data.aws_iam_policy_document.publish.json
}
