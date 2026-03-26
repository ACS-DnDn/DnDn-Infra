variable "project" {
  description = "프로젝트명"
  type        = string
}

variable "environment" {
  description = "배포 환경 (PRD / DEV)"
  type        = string
}

# ── 초기 시드 값 (최초 apply 시 사용, 이후 ignore_changes) ──────────────

variable "api_database_url" {
  description = "API pod SQLALCHEMY_DATABASE_URL"
  type        = string
  default     = "PLACEHOLDER"
  sensitive   = true
}

variable "report_database_url" {
  description = "Report pod DATABASE_URL"
  type        = string
  default     = "PLACEHOLDER"
  sensitive   = true
}

variable "internal_api_key" {
  description = "Lambda↔API 내부 인증 공유 시크릿"
  type        = string
  default     = "PLACEHOLDER"
  sensitive   = true
}

variable "sts_external_id" {
  description = "고객 계정 AssumeRole External ID"
  type        = string
  default     = "PLACEHOLDER"
  sensitive   = true
}

variable "github_client_id" {
  description = "GitHub OAuth App Client ID"
  type        = string
  default     = "PLACEHOLDER"
}

variable "github_client_secret" {
  description = "GitHub OAuth App Client Secret"
  type        = string
  default     = "PLACEHOLDER"
  sensitive   = true
}

variable "slack_client_id" {
  description = "Slack OAuth App Client ID"
  type        = string
  default     = "PLACEHOLDER"
}

variable "slack_client_secret" {
  description = "Slack OAuth App Client Secret"
  type        = string
  default     = "PLACEHOLDER"
  sensitive   = true
}

variable "github_webhook_secret" {
  description = "GitHub Webhook HMAC-SHA256 시크릿"
  type        = string
  default     = "PLACEHOLDER"
  sensitive   = true
}
