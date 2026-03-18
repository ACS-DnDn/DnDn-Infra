variable "project" {
  description = "프로젝트명"
  type        = string
}

variable "environment" {
  description = "배포 환경 (PRD / DEV)"
  type        = string
}

variable "instance_class" {
  description = "RDS 인스턴스 타입"
  type        = string
  default     = "db.t3.medium"
}

variable "db_name" {
  description = "데이터베이스명"
  type        = string
  default     = "dndn"
}

variable "db_username" {
  description = "마스터 유저명"
  type        = string
  default     = "dndn_app"
}

variable "private_subnet_ids" {
  description = "프라이빗 서브넷 ID 목록 [2a, 2c]"
  type        = list(string)
}

variable "rds_sg_id" {
  description = "RDS SG ID"
  type        = string
}
