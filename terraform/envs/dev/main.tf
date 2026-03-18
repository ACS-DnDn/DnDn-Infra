data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ── VPC ───────────────────────────────────────────────────────────────────

module "vpc" {
  source = "../../modules/vpc"

  project     = var.project
  environment = var.environment

  vpc_cidr             = "10.251.0.0/16"
  azs                  = ["ap-northeast-2a", "ap-northeast-2c"]
  public_subnet_cidrs  = ["10.251.1.0/24", "10.251.11.0/24"]
  private_subnet_cidrs = ["10.251.2.0/24", "10.251.12.0/24"]
}

# ── Security Groups ───────────────────────────────────────────────────────

module "security_groups" {
  source = "../../modules/security_groups"

  project     = var.project
  environment = var.environment

  vpc_id = module.vpc.vpc_id
}

# ── SQS ──────────────────────────────────────────────────────────────────

module "sqs" {
  source = "../../modules/sqs"

  project     = var.project
  environment = var.environment
}

# ── S3 ───────────────────────────────────────────────────────────────────

module "s3" {
  source = "../../modules/s3"

  project     = var.project
  environment = var.environment

  s3_event_queue_arn = module.sqs.s3_event_queue_arn
}

# ── DB Secret (MariaDB on EC2) ────────────────────────────────────────────
# Lambda enricher가 Secrets Manager로 DB 자격증명을 조회하므로
# EC2의 MariaDB 접속 정보를 PRD RDS와 동일한 방식으로 저장

resource "aws_secretsmanager_secret" "dev_db" {
  name                    = "dndn-dev-mariadb"
  recovery_window_in_days = 0 # DEV: terraform destroy 시 즉시 삭제
}

resource "aws_secretsmanager_secret_version" "dev_db" {
  secret_id = aws_secretsmanager_secret.dev_db.id

  secret_string = jsonencode({
    host     = var.ec2_private_ip
    port     = 3306
    dbname   = "dndn"
    username = var.db_user
    password = var.db_password
  })
}

# ── Lambda ────────────────────────────────────────────────────────────────
# finding_enricher, health_enricher, scheduler_trigger
# PRD와 동일 모듈 — DEV RDS Secret + EC2 API URL만 변경

module "lambda" {
  source = "../../modules/lambda"

  project     = var.project
  environment = var.environment

  private_subnet_ids = module.vpc.private_subnet_ids
  lambda_sg_id       = module.security_groups.lambda_sg_id
  s3_bucket_name     = module.s3.bucket_name
  rds_secret_arn     = aws_secretsmanager_secret.dev_db.arn
  api_internal_url   = "http://${var.ec2_private_ip}:8000"
  internal_api_key   = var.internal_api_key
}

# ── EventBridge ───────────────────────────────────────────────────────────

module "eventbridge" {
  source = "../../modules/eventbridge"

  project     = var.project
  environment = var.environment

  allowed_account_ids  = var.allowed_account_ids
  finding_enricher_arn = module.lambda.finding_enricher_arn
  health_enricher_arn  = module.lambda.health_enricher_arn
}

# ── EventBridge Scheduler 실행 Role ───────────────────────────────────────
# PRD의 iam_irsa 모듈 대신 DEV는 직접 리소스로 생성

resource "aws_scheduler_schedule_group" "dndn_schedules" {
  name = "dndn-dev-schedules"

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_iam_role" "scheduler" {
  name = "DnDn-DEV-EBS-SchedulerRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          "aws:SourceArn"     = "arn:aws:scheduler:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:schedule/${aws_scheduler_schedule_group.dndn_schedules.name}/*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "scheduler_lambda" {
  name = "LambdaInvokePolicy"
  role = aws_iam_role.scheduler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = module.lambda.scheduler_trigger_arn
    }]
  })
}

# ── EC2 (앱 서버 + MariaDB) ───────────────────────────────────────────────

module "ec2" {
  source = "../../modules/ec2"

  project     = var.project
  environment = var.environment

  vpc_id           = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnet_ids[0]
  private_ip       = var.ec2_private_ip
  lambda_sg_id     = module.security_groups.lambda_sg_id
  instance_type    = "t3.large"

  s3_bucket_name           = module.s3.bucket_name
  report_request_queue_arn = module.sqs.report_request_queue_arn
  s3_event_queue_arn       = module.sqs.s3_event_queue_arn

  db_user       = var.db_user
  db_password   = var.db_password
  db_secret_arn = aws_secretsmanager_secret.dev_db.arn

  scheduler_role_arn   = aws_iam_role.scheduler.arn
  scheduler_group_name = aws_scheduler_schedule_group.dndn_schedules.name
}
