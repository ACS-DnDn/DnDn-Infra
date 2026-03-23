locals {
  prefix = "${lower(var.project)}-${lower(var.environment)}"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ── 더미 배포 패키지 (초기 인프라 생성용) ─────────────────────────────────────
# CI/CD가 실제 코드를 aws lambda update-function-code로 교체함

data "archive_file" "dummy" {
  type        = "zip"
  output_path = "${path.module}/dummy.zip"

  source {
    content  = "def handler(event, context): return {'statusCode': 200}"
    filename = "index.py"
  }
}

# ── Lambda IAM Role ───────────────────────────────────────────────────────

resource "aws_iam_role" "lambda" {
  name = "${var.project}-${var.environment}-Lambda-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "vpc_access" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_custom" {
  name = "LambdaCustomPolicy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${var.s3_bucket_name}/canonical/*"
      },
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = "arn:aws:iam::*:role/DnDnOpsAgentRole"
      },
      {
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = var.rds_secret_arn
      }
    ]
  })
}

# ── finding-enricher ──────────────────────────────────────────────────────

resource "aws_lambda_function" "finding_enricher" {
  function_name    = "${local.prefix}-lmd-finding-enricher"
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  handler          = "finding_enricher.handler"
  timeout          = 30
  memory_size      = 256
  filename         = data.archive_file.dummy.output_path
  source_code_hash = data.archive_file.dummy.output_base64sha256

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_sg_id]
  }

  environment {
    variables = {
      OUTPUT_BUCKET           = var.s3_bucket_name
      RDS_SECRET_ARN          = var.rds_secret_arn
      CUSTOMER_ROLE_NAME      = "DnDnOpsAgentRole"
      ASSUME_ROLE_EXTERNAL_ID = ""
    }
  }

  tags = {
    Name = "${local.prefix}-lmd-finding-enricher"
  }

  lifecycle {
    ignore_changes = [filename, source_code_hash]
  }
}

# ── health-enricher ───────────────────────────────────────────────────────

resource "aws_lambda_function" "health_enricher" {
  function_name    = "${local.prefix}-lmd-health-enricher"
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  handler          = "health_enricher.handler"
  timeout          = 30
  memory_size      = 256
  filename         = data.archive_file.dummy.output_path
  source_code_hash = data.archive_file.dummy.output_base64sha256

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_sg_id]
  }

  environment {
    variables = {
      OUTPUT_BUCKET           = var.s3_bucket_name
      RDS_SECRET_ARN          = var.rds_secret_arn
      CUSTOMER_ROLE_NAME      = "DnDnOpsAgentRole"
      ASSUME_ROLE_EXTERNAL_ID = ""
    }
  }

  tags = {
    Name = "${local.prefix}-lmd-health-enricher"
  }

  lifecycle {
    ignore_changes = [filename, source_code_hash]
  }
}

# ── scheduler-trigger ─────────────────────────────────────────────────────

resource "aws_lambda_function" "scheduler_trigger" {
  function_name    = "${local.prefix}-lmd-scheduler-trigger"
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  handler          = "handler.handler"
  timeout          = 30
  memory_size      = 128
  filename         = data.archive_file.dummy.output_path
  source_code_hash = data.archive_file.dummy.output_base64sha256

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_sg_id]
  }

  environment {
    variables = {
      API_INTERNAL_URL = var.api_internal_url
      INTERNAL_API_KEY = var.internal_api_key
    }
  }

  tags = {
    Name = "${local.prefix}-lmd-scheduler-trigger"
  }

  lifecycle {
    ignore_changes = [filename, source_code_hash]
  }
}

# EventBridge Scheduler → Lambda 실행 권한
resource "aws_lambda_permission" "scheduler_trigger" {
  statement_id  = "AllowEventBridgeScheduler"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scheduler_trigger.function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = "arn:aws:scheduler:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:schedule/${var.scheduler_group_name}/*"
}
