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
