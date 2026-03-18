output "s3_event_queue_arn" {
  description = "S3 이벤트 큐 ARN"
  value       = aws_sqs_queue.s3_event.arn
}

output "s3_event_queue_url" {
  description = "S3 이벤트 큐 URL"
  value       = aws_sqs_queue.s3_event.url
}

output "report_request_queue_arn" {
  description = "현황보고서 요청 큐 ARN"
  value       = aws_sqs_queue.report_request.arn
}

output "report_request_queue_url" {
  description = "현황보고서 요청 큐 URL"
  value       = aws_sqs_queue.report_request.url
}
