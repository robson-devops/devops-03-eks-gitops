output "role_arn" {
  description = "ARN da role assumida pelo controller via IRSA"
  value       = aws_iam_role.main.arn
}
