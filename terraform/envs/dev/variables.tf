variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "배포 환경"
  type        = string
  default     = "DEV"
}

variable "project" {
  description = "프로젝트명"
  type        = string
  default     = "DnDn"
}

variable "allowed_account_ids" {
  description = "이벤트를 전송할 수 있는 고객 계정 ID 목록 (EventBridge 크로스 계정 허용)"
  type        = list(string)
  default     = []
}

variable "ec2_private_ip" {
  # 퍼블릭 서브넷 10.251.1.0/24 내 고정 IP
  # Lambda scheduler-trigger → "http://${ec2_private_ip}:8000" 으로 API 호출
  description = "DEV EC2 고정 사설 IP"
  type        = string
  default     = "10.251.1.10"
}

variable "db_user" {
  description = "MariaDB 사용자 이름"
  type        = string
  default     = "dndn_user"
}

variable "db_password" {
  description = "MariaDB 비밀번호"
  type        = string
  sensitive   = true
}

variable "internal_api_key" {
  description = "Lambda → API 서버 내부 인증 공유 시크릿 (X-Internal-Key 헤더)"
  type        = string
  sensitive   = true
}
