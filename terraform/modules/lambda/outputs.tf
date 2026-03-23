output "finding_enricher_arn" {
  description = "finding-enricher Lambda ARN"
  value       = aws_lambda_function.finding_enricher.arn
}

output "health_enricher_arn" {
  description = "health-enricher Lambda ARN"
  value       = aws_lambda_function.health_enricher.arn
}

output "scheduler_trigger_arn" {
  description = "scheduler-trigger Lambda ARN — EventBridge Scheduler SCHEDULER_TARGET_ARN에 사용"
  value       = aws_lambda_function.scheduler_trigger.arn
}
