# ── VPC ──────────────────────────────────────────────────────────────────

module "vpc" {
  source = "../../modules/vpc"

  project     = var.project
  environment = var.environment

  vpc_cidr             = "10.250.0.0/16"
  azs                  = ["ap-northeast-2a", "ap-northeast-2c"]
  public_subnet_cidrs  = ["10.250.1.0/24", "10.250.11.0/24"]
  private_subnet_cidrs = ["10.250.2.0/24", "10.250.12.0/24"]
}

# ── Security Groups ──────────────────────────────────────────────────────────

module "security_groups" {
  source = "../../modules/security_groups"

  project     = var.project
  environment = var.environment

  vpc_id = module.vpc.vpc_id
}

# ── Bastion ──────────────────────────────────────────────────────────────────

module "bastion" {
  source = "../../modules/bastion"

  project     = var.project
  environment = var.environment

  public_subnet_id = module.vpc.public_subnet_ids[0]
  bastion_sg_id    = module.security_groups.bastion_sg_id
}

# ── ECR ──────────────────────────────────────────────────────────────────────

module "ecr" {
  source = "../../modules/ecr"

  project     = var.project
  environment = var.environment
}

# ── RDS ──────────────────────────────────────────────────────────────────────

module "rds" {
  source = "../../modules/rds"

  project     = var.project
  environment = var.environment

  private_subnet_ids = module.vpc.private_subnet_ids
  rds_sg_id          = module.security_groups.rds_sg_id
}

# ── EKS ──────────────────────────────────────────────────────────────────────

module "eks" {
  source = "../../modules/eks"

  project     = var.project
  environment = var.environment

  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids
  node_sg_id         = module.security_groups.node_sg_id

  admin_role_arns = [module.bastion.role_arn]
}

# ── SQS ──────────────────────────────────────────────────────────────────────

module "sqs" {
  source = "../../modules/sqs"

  project     = var.project
  environment = var.environment
}

# ── IAM / IRSA ───────────────────────────────────────────────────────────────

module "iam_irsa" {
  source = "../../modules/iam_irsa"

  project     = var.project
  environment = var.environment

  oidc_provider_arn        = module.eks.oidc_provider_arn
  oidc_provider_url        = module.eks.oidc_provider_url
  report_request_queue_arn = module.sqs.report_request_queue_arn
  s3_event_queue_arn       = module.sqs.s3_event_queue_arn
  s3_bucket_name           = module.s3.bucket_name
  cognito_user_pool_arn    = module.cognito.user_pool_arn
}

# ── S3 ───────────────────────────────────────────────────────────────────────

module "s3" {
  source = "../../modules/s3"

  project     = var.project
  environment = var.environment

  s3_event_queue_arn = module.sqs.s3_event_queue_arn
}

# ── Lambda ───────────────────────────────────────────────────────────────────

module "lambda" {
  source = "../../modules/lambda"

  project     = var.project
  environment = var.environment

  private_subnet_ids = module.vpc.private_subnet_ids
  lambda_sg_id       = module.security_groups.lambda_sg_id
  s3_bucket_name     = module.s3.bucket_name
  rds_secret_arn     = module.rds.master_user_secret_arn
  api_internal_url   = var.api_internal_url
  internal_api_key   = var.internal_api_key
}

# ── Cognito ──────────────────────────────────────────────────────────────

module "cognito" {
  source = "../../modules/cognito"

  project     = var.project
  environment = var.environment

  # 기존 DEV Pool 재사용 (import 후 이름 drift 방지)
  user_pool_name  = "DnDn_UserPool_DEV"
  app_client_name = "DnDn_AppClient_DEV"
}

# ── EventBridge ───────────────────────────────────────────────────────────

module "eventbridge" {
  source = "../../modules/eventbridge"

  project     = var.project
  environment = var.environment

  allowed_account_ids  = var.allowed_account_ids
  finding_enricher_arn = module.lambda.finding_enricher_arn
  health_enricher_arn  = module.lambda.health_enricher_arn
  # worker_lambda_arn: Worker Lambda 배포 후 추가
}

# ── Route53 ──────────────────────────────────────────────────────────────

module "route53" {
  source = "../../modules/route53"

  project     = var.project
  environment = var.environment

  # TODO: ALB Controller 배포 후 아래 주석 해제 + terraform apply 재실행
  # alb_dns_name = "xxx.ap-northeast-2.elb.amazonaws.com"
  # alb_hosted_zone_id 기본값 ZWKZPGTI48KDX (ap-northeast-2) — 타 리전 배포 시 변경 필요
}

# ── ACM ───────────────────────────────────────────────────────────────────
# 1차 apply 후 주석 해제 (Route53 zone이 존재해야 DNS 검증 가능)

# module "acm" {
#   source = "../../modules/acm"
#
#   project     = var.project
#   environment = var.environment
#
#   route53_zone_id    = module.route53.zone_id
#   hr_route53_zone_id = module.route53.hr_zone_id
# }

# ── S3 Public (고객 배포용 CFN 템플릿) ───────────────────────────────────────
# dndn-public 버킷은 DEV/PRD 공유 — 수동 생성 후 data 소스로 참조
# aws s3api create-bucket --bucket dndn-public --region ap-northeast-2 --create-bucket-configuration LocationConstraint=ap-northeast-2

data "aws_s3_bucket" "public" {
  bucket = "dndn-public"
}

# ── ALB Controller (Helm) ────────────────────────────────────────────────
# 1차 apply(EKS 생성) 후 주석 해제하여 2차 apply
# Helm provider가 EKS endpoint에 의존하므로 EKS 없이는 init 불가

# module "alb_controller" {
#   source = "../../modules/alb_controller"
#
#   project     = var.project
#   environment = var.environment
#
#   cluster_name      = module.eks.cluster_name
#   oidc_provider_arn = module.eks.oidc_provider_arn
#   oidc_provider_url = module.eks.oidc_provider_url
#   vpc_id            = module.vpc.vpc_id
# }
