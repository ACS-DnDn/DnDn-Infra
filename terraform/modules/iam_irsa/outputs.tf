output "api_role_arn" {
  description = "API pod IRSA Role ARN"
  value       = aws_iam_role.api.arn
}

output "worker_role_arn" {
  description = "Worker pod IRSA Role ARN"
  value       = aws_iam_role.worker.arn
}

output "reporter_role_arn" {
  description = "Reporter pod IRSA Role ARN"
  value       = aws_iam_role.reporter.arn
}

output "scheduler_role_arn" {
  description = "EventBridge Scheduler 실행 Role ARN"
  value       = aws_iam_role.scheduler.arn
}
