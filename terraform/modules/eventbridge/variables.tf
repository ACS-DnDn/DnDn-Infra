variable "project" {
  description = "프로젝트명"
  type        = string
}

variable "environment" {
  description = "배포 환경 (PRD / DEV)"
  type        = string
}

variable "allowed_account_ids" {
  description = "이벤트를 전송할 수 있는 고객 계정 ID 목록"
  type        = list(string)
}

variable "finding_enricher_arn" {
  description = "SecurityHub Finding 처리 Lambda ARN"
  type        = string
}

variable "health_enricher_arn" {
  description = "AWS Health 이벤트 처리 Lambda ARN"
  type        = string
}

variable "worker_lambda_arn" {
  description = "CloudTrail/Config 이벤트 처리 Worker Lambda ARN (미배포 시 빈 문자열)"
  type        = string
  default     = ""
}
