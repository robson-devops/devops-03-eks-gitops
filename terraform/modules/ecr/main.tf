resource "aws_ecr_repository" "main" {
  # checkov:skip=CKV_AWS_136: AES256 com chave gerenciada pela AWS basta aqui.
  name         = var.name
  force_delete = var.force_delete

  # Tag publicada não muda de conteúdo; o pipeline usa só o SHA do commit.
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = var.name
  }
}

resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expira imagens sem tag apos ${var.untagged_image_retention_day} dias"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_image_retention_day
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Mantem apenas as ${var.tagged_image_count} imagens com tag mais recentes"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.tagged_image_count
        }
        action = {
          type = "expire"
        }
      },
    ]
  })
}
