terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    # helm과 kubernetes provider는 EKS 생성 후 2차 apply 시 활성화
    # helm = {
    #   source  = "hashicorp/helm"
    #   version = "~> 2.17"
    # }
    # kubernetes = {
    #   source  = "hashicorp/kubernetes"
    #   version = "~> 2.36"
    # }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# ── EKS 인증 데이터 (Helm / Kubernetes provider 공통) ─────────────────────
# 1차 apply 후 아래 주석 해제 (EKS 생성 완료 후)

# data "aws_eks_cluster_auth" "main" {
#   name = module.eks.cluster_name
# }

# provider "helm" {
#   kubernetes {
#     host                   = module.eks.cluster_endpoint
#     cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
#     token                  = data.aws_eks_cluster_auth.main.token
#   }
# }

# provider "kubernetes" {
#   host                   = module.eks.cluster_endpoint
#   cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
#   token                  = data.aws_eks_cluster_auth.main.token
# }
