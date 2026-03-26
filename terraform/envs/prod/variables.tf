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
  # Lambda는 EKS CoreDNS를 사용하지 않으므로 K8s 서비스 DNS 불가.
  # Internal ALB 배포 후 DNS 이름으로 설정할 것.
  # 예: http://internal-xxx.ap-northeast-2.elb.amazonaws.com
  description = "API 서버 Internal ALB URL (ALB 배포 후 설정, scheduler-trigger Lambda 환경변수)"
  type        = string
}

variable "internal_api_key" {
  description = "Lambda → API 서버 내부 인증 공유 시크릿 (X-Internal-Key 헤더)"
  type        = string
  sensitive   = true
}

variable "alb_dns_name" {
  description = "K8s ALB Controller가 생성한 ALB DNS 이름 (Ingress 배포 후 설정)"
  type        = string
  default     = ""
}

variable "assume_role_external_id" {
  description = "고객 계정 DnDnOpsAgentRole AssumeRole External ID"
  type        = string
  default     = "DnDnExternalId"
}
