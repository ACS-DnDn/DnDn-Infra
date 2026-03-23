variable "project" {
  description = "프로젝트명"
  type        = string
}

variable "environment" {
  description = "배포 환경 (PRD / DEV)"
  type        = string
}

variable "cluster_version" {
  description = "EKS 클러스터 버전"
  type        = string
  default     = "1.32"
}

variable "node_instance_type" {
  description = "노드 EC2 인스턴스 타입"
  type        = string
  default     = "t3.medium"
}

variable "node_min" {
  description = "노드 최소 수"
  type        = number
  default     = 1
}

variable "node_desired" {
  description = "노드 희망 수"
  type        = number
  default     = 2
}

variable "node_max" {
  description = "노드 최대 수"
  type        = number
  default     = 4
}

variable "public_subnet_ids" {
  description = "퍼블릭 서브넷 ID 목록"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "프라이빗 서브넷 ID 목록"
  type        = list(string)
}

variable "node_sg_id" {
  description = "EKS 노드 추가 SG ID"
  type        = string
}

variable "admin_role_arns" {
  description = "EKS 클러스터 관리자 IAM Role ARN 목록 (Bastion, 개인 등)"
  type        = list(string)
  default     = []
}
