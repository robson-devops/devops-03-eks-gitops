output "role_arn" {
  description = "ARN da role do Alertmanager, anotada na service account em gitops/apps/monitoring.yaml"
  value       = aws_iam_role.main.arn
}

output "topic_arn" {
  description = "ARN do tópico SNS usado em gitops/apps/monitoring.yaml"
  value       = aws_sns_topic.main.arn
}
