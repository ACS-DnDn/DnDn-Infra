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

output "external_secrets_role_arn" {
  description = "External Secrets controller IRSA Role ARN"
  value       = aws_iam_role.external_secrets.arn
}

output "scheduler_role_arn" {
  description = "EventBridge Scheduler 실행 Role ARN"
  value       = aws_iam_role.scheduler.arn
}

output "scheduler_group_name" {
  description = "EventBridge Scheduler 스케줄 그룹 이름"
  value       = aws_scheduler_schedule_group.dndn_schedules.name
}

output "gha_terraform_role_arn" {
  description = "GitHub Actions Terraform Role ARN"
  value       = aws_iam_role.gha_terraform.arn
}

output "gha_deploy_role_arn" {
  description = "GitHub Actions Deploy Role ARN"
  value       = aws_iam_role.gha_deploy.arn
}
