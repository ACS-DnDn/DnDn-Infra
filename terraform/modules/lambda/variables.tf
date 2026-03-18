variable "project" {
  description = "프로젝트명"
  type        = string
}

variable "environment" {
  description = "배포 환경 (PRD / DEV)"
  type        = string
}

variable "private_subnet_ids" {
  description = "Lambda VPC 서브넷 ID 목록"
  type        = list(string)
}

variable "lambda_sg_id" {
  description = "Lambda SG ID"
  type        = string
}

variable "s3_bucket_name" {
  description = "S3 버킷 이름"
  type        = string
}

variable "event_report_queue_arn" {
  description = "이벤트보고서 SQS ARN"
  type        = string
}

variable "event_report_queue_url" {
  description = "이벤트보고서 SQS URL"
  type        = string
}

variable "rds_secret_arn" {
  description = "RDS 자격증명 Secrets Manager ARN"
  type        = string
}

variable "lambda_code_bucket" {
  description = "Lambda 배포 코드가 업로드되는 S3 버킷 이름"
  type        = string
  default     = "dndn-prd-s3"
}
