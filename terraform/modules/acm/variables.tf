variable "project" {
  description = "프로젝트명"
  type        = string
}

variable "environment" {
  description = "배포 환경 (PRD / DEV)"
  type        = string
}

variable "domain" {
  description = "인증서 기본 도메인 (예: dndn.cloud)"
  type        = string
  default     = "dndn.cloud"
}

variable "route53_zone_id" {
  description = "dndn.cloud DNS 검증 레코드를 생성할 Route53 Hosted Zone ID"
  type        = string
}

variable "hr_domain" {
  description = "HR 앱 인증서 도메인 (예: dndnhr.cloud)"
  type        = string
  default     = "dndnhr.cloud"
}

variable "hr_route53_zone_id" {
  description = "dndnhr.cloud DNS 검증 레코드를 생성할 Route53 Hosted Zone ID"
  type        = string
}
