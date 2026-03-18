variable "project" {
  description = "프로젝트명"
  type        = string
}

variable "environment" {
  description = "배포 환경 (PRD / DEV)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_id" {
  description = "EC2가 배치될 퍼블릭 서브넷 ID"
  type        = string
}

variable "private_ip" {
  description = "EC2 고정 사설 IP (Lambda scheduler-trigger → API 호출 URL에 사용)"
  type        = string
  default     = "10.251.1.10"
}

variable "lambda_sg_id" {
  description = "Lambda Security Group ID (MariaDB 3306, API 8000 포트 허용 대상)"
  type        = string
}

variable "instance_type" {
  description = "EC2 인스턴스 타입"
  type        = string
  default     = "t3.large"
}

variable "s3_bucket_name" {
  description = "S3 버킷 이름"
  type        = string
}

variable "report_request_queue_arn" {
  description = "report-request SQS Queue ARN"
  type        = string
}

variable "s3_event_queue_arn" {
  description = "s3-event SQS Queue ARN"
  type        = string
}

variable "db_name" {
  description = "MariaDB 데이터베이스 이름"
  type        = string
  default     = "dndn"
}

variable "db_user" {
  description = "MariaDB 사용자 이름"
  type        = string
}

variable "db_password" {
  description = "MariaDB 비밀번호"
  type        = string
  sensitive   = true
}

variable "db_secret_arn" {
  description = "Secrets Manager Secret ARN (DB 자격증명 — Lambda enricher 환경변수 RDS_SECRET_ARN에 사용)"
  type        = string
}

variable "scheduler_role_arn" {
  description = "EventBridge Scheduler 실행 Role ARN (EC2 API → iam:PassRole 대상)"
  type        = string
}

variable "scheduler_group_name" {
  description = "EventBridge Scheduler 스케줄 그룹 이름"
  type        = string
}
