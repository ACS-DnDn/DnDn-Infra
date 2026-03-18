variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "배포 환경 (PRD / DEV)"
  type        = string
  default     = "PRD"
}

variable "project" {
  description = "프로젝트명"
  type        = string
  default     = "DnDn"
}

variable "platform_account_id" {
  description = "Platform AWS Account ID"
  type        = string
  default     = "387721658341"
}

variable "allowed_account_ids" {
  description = "이벤트를 전송할 수 있는 고객 계정 ID 목록 (EventBridge 크로스 계정 허용)"
  type        = list(string)
  default     = []
}

variable "api_internal_url" {
  description = "API 서버 K8s 내부 서비스 URL (scheduler-trigger Lambda 환경변수)"
  type        = string
  default     = "http://api-service.dndn-api.svc.cluster.local"
}

variable "internal_api_key" {
  description = "Lambda → API 서버 내부 인증 공유 시크릿 (X-Internal-Key 헤더)"
  type        = string
  sensitive   = true
}
