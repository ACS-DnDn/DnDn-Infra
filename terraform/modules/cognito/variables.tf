variable "project" {
  description = "프로젝트명"
  type        = string
}

variable "environment" {
  description = "배포 환경 (PRD / DEV)"
  type        = string
}

variable "user_pool_name" {
  description = "Cognito User Pool 이름 (기존 Pool 재사용 시 지정)"
  type        = string
  default     = ""
}

variable "app_client_name" {
  description = "Cognito App Client 이름 (기존 Client 재사용 시 지정)"
  type        = string
  default     = ""
}
