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
  event_report_queue_arn   = module.sqs.event_report_queue_arn
  s3_bucket_name           = module.s3.bucket_name
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

  private_subnet_ids     = module.vpc.private_subnet_ids
  lambda_sg_id           = module.security_groups.lambda_sg_id
  s3_bucket_name         = module.s3.bucket_name
  event_report_queue_arn = module.sqs.event_report_queue_arn
  event_report_queue_url = module.sqs.event_report_queue_url
  rds_secret_arn         = module.rds.master_user_secret_arn
}

# ── Cognito ──────────────────────────────────────────────────────────────

module "cognito" {
  source = "../../modules/cognito"

  project     = var.project
  environment = var.environment
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

module "acm" {
  source = "../../modules/acm"

  project     = var.project
  environment = var.environment

  route53_zone_id = module.route53.zone_id
}

# ── 추후 추가 예정 ────────────────────────────────────────────────────────
# module "alb_controller"  { ... }
