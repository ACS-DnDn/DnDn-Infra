output "finding_enricher_arn" {
  description = "finding-enricher Lambda ARN"
  value       = aws_lambda_function.finding_enricher.arn
}

output "health_enricher_arn" {
  description = "health-enricher Lambda ARN"
  value       = aws_lambda_function.health_enricher.arn
}
