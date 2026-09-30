output "role_arn" {
  description = "ARN da role do pipeline, usado no secret AWS_ROLE_ARN do repositório"
  value       = aws_iam_role.pipeline.arn
}
