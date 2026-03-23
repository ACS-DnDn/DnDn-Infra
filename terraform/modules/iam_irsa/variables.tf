variable "project" {
  description = "프로젝트명"
  type        = string
}

variable "environment" {
  description = "배포 환경 (PRD / DEV)"
  type        = string
}

variable "oidc_provider_arn" {
  description = "EKS OIDC Provider ARN"
  type        = string
}

variable "oidc_provider_url" {
  description = "EKS OIDC Provider URL"
  type        = string
}

variable "github_org" {
  description = "GitHub 조직명 (OIDC trust 조건에 사용)"
  type        = string
  default     = "ACS-DnDn"
}

variable "s3_bucket_name" {
  description = "S3 버킷 이름"
  type        = string
  default     = "dndn-prd-s3"
}

variable "report_request_queue_arn" {
  description = "보고서 요청 SQS Queue ARN (dndn-prd-sqs-report-request)"
  type        = string
}

variable "s3_event_queue_arn" {
  description = "S3 이벤트 SQS Queue ARN (dndn-prd-sqs-s3-event) — Reporter 컨슘"
  type        = string
}

variable "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN (API 로그인/사용자 관리용)"
  type        = string
}
