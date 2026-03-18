variable "project" {
  description = "프로젝트명"
  type        = string
}

variable "environment" {
  description = "배포 환경 (PRD / DEV)"
  type        = string
}

variable "domain" {
  description = "Route53 호스팅 존 도메인 (예: dndn.cloud)"
  type        = string
  default     = "dndn.cloud"
}

variable "alb_dns_name" {
  description = "ALB DNS 이름 (EKS ALB Controller 배포 후 입력)"
  type        = string
  default     = ""
}

variable "alb_hosted_zone_id" {
  description = "ALB Hosted Zone ID (리전별 고정값, ap-northeast-2 = ZWKZPGTI48KDX)"
  type        = string
  default     = "ZWKZPGTI48KDX"
}
