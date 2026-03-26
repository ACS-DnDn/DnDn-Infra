output "api_secret_arn" {
  description = "API pod ExternalSecrets가 참조하는 Secret ARN"
  value       = aws_secretsmanager_secret.api.arn
}

output "report_secret_arn" {
  description = "Report pod ExternalSecrets가 참조하는 Secret ARN"
  value       = aws_secretsmanager_secret.report.arn
}
