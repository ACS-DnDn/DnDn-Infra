output "event_bus_arn" {
  description = "EventBus ARN (고객 CFN의 DnDnEventBusArn 파라미터에 입력)"
  value       = aws_cloudwatch_event_bus.main.arn
}

output "event_bus_name" {
  description = "EventBus 이름"
  value       = aws_cloudwatch_event_bus.main.name
}

output "worker_assume_policy_arn" {
  description = "Worker/Lambda IAM Role에 붙일 정책 ARN"
  value       = aws_iam_policy.worker_assume.arn
}

output "log_group_name" {
  description = "이벤트 로그 그룹 이름"
  value       = aws_cloudwatch_log_group.events.name
}
