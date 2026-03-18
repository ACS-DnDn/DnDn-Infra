variable "project" {
  description = "프로젝트명"
  type        = string
}

variable "environment" {
  description = "배포 환경 (PRD / DEV)"
  type        = string
}

variable "s3_event_queue_arn" {
  description = "S3 이벤트 알림 대상 SQS ARN (dndn-prd-sqs-s3-event)"
  type        = string
}
