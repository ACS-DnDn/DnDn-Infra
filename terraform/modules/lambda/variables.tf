variable "project" {
  description = "프로젝트명"
  type        = string
}

variable "environment" {
  description = "배포 환경 (PRD / DEV)"
  type        = string
}

variable "private_subnet_ids" {
  description = "Lambda VPC 서브넷 ID 목록"
  type        = list(string)
}

variable "lambda_sg_id" {
  description = "Lambda SG ID"
  type        = string
}

variable "s3_bucket_name" {
  description = "S3 버킷 이름"
  type        = string
}

variable "rds_secret_arn" {
  description = "RDS 자격증명 Secrets Manager ARN"
  type        = string
}

variable "scheduler_group_name" {
  description = "EventBridge Scheduler 그룹 이름 (Lambda permission source_arn 제한용)"
  type        = string
  default     = "dndn-schedules"
}

variable "api_internal_url" {
  # Lambda는 VPC DNS를 쓰지만 EKS CoreDNS를 거치지 않으므로 K8s 서비스 DNS 사용 불가.
  # Internal ALB 배포 후 DNS 이름으로 설정할 것.
  # 예: http://internal-xxx.ap-northeast-2.elb.amazonaws.com
  description = "API 서버 Internal ALB URL (scheduler-trigger Lambda → API 호출, ALB 배포 후 설정)"
  type        = string
}

variable "internal_api_key" {
  description = "Lambda → API 서버 내부 인증 공유 시크릿 (X-Internal-Key 헤더)"
  type        = string
  sensitive   = true
}
