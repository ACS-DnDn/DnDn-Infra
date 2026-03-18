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

variable "namespace" {
  description = "Kubernetes 네임스페이스"
  type        = string
  default     = "dndn-prd"
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
