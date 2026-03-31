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
  bastion_sg_id   = module.security_groups.bastion_sg_id
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

  private_subnet_ids      = module.vpc.private_subnet_ids
  lambda_sg_id            = module.security_groups.lambda_sg_id
  s3_bucket_name          = module.s3.bucket_name
  rds_secret_arn          = module.rds.app_secret_arn
  api_internal_url        = var.api_internal_url
  internal_api_key        = var.internal_api_key
  assume_role_external_id = var.assume_role_external_id
}

# ── Cognito ──────────────────────────────────────────────────────────────

module "cognito" {
  source = "../../modules/cognito"

  project     = var.project
  environment = var.environment

  # prod에서 재사용 중인 DEV Cognito 리소스와 이름 충돌이 나지 않도록
  # reserved suffix를 사용한 별도 이름을 명시한다.
  user_pool_name  = var.cognito_user_pool_name
  app_client_name = var.cognito_app_client_name
}

# ── EventBridge ───────────────────────────────────────────────────────────

module "eventbridge" {
  count  = var.manage_eventbridge ? 1 : 0
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
  count  = var.manage_public_dns ? 1 : 0
  source = "../../modules/route53"

  project     = var.project
  environment = var.environment

  domain       = var.domain
  hr_domain    = var.hr_domain
  alb_dns_name = var.alb_dns_name
}

# ── ACM ───────────────────────────────────────────────────────────────────

module "acm" {
  count  = var.manage_public_dns ? 1 : 0
  source = "../../modules/acm"

  project     = var.project
  environment = var.environment

  domain             = var.domain
  hr_domain          = var.hr_domain
  route53_zone_id    = module.route53[0].zone_id
  hr_route53_zone_id = module.route53[0].hr_zone_id
}

# ── S3 Public (고객 배포용 CFN 템플릿 + 회사 로고) ─────────────────────────

module "s3_public" {
  count  = var.manage_public_assets_bucket ? 1 : 0
  source = "../../modules/s3_public"
}

# ── App Secrets (K8s ExternalSecrets 참조) ──────────────────────────────────

module "app_secrets" {
  source = "../../modules/app_secrets"

  project     = var.project
  environment = var.environment
}

# ── ALB Controller (Helm) ────────────────────────────────────────────────

module "alb_controller" {
  source = "../../modules/alb_controller"

  project     = var.project
  environment = var.environment

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  vpc_id            = module.vpc.vpc_id

  # EKS private endpoint만 사용 → Helm은 Bastion에서 수동 설치
  install_helm = false
}
