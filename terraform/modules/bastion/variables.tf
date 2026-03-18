variable "project" {
  description = "프로젝트명"
  type        = string
}

variable "environment" {
  description = "배포 환경 (PRD / DEV)"
  type        = string
}

variable "instance_type" {
  description = "EC2 인스턴스 타입"
  type        = string
  default     = "t3.micro"
}

variable "public_subnet_id" {
  description = "Bastion을 배치할 퍼블릭 서브넷 ID (PUB-2A)"
  type        = string
}

variable "bastion_sg_id" {
  description = "Bastion SG ID"
  type        = string
}

variable "key_pair_name" {
  description = "EC2 Key Pair 이름"
  type        = string
  default     = "DnDn-PRD-KeyPair"
}
