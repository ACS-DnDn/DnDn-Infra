locals {
  prefix = "${lower(var.project)}-${lower(var.environment)}"
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
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.rds_secret_arn
      }
    ]
  })
}

# ── finding-enricher ──────────────────────────────────────────────────────

resource "aws_lambda_function" "finding_enricher" {
  function_name = "${local.prefix}-lmd-finding-enricher"
  role          = aws_iam_role.lambda.arn
  runtime       = "python3.12"
  handler       = "finding_enricher.handler"
  timeout       = 30
  memory_size   = 256

  # 배포 패키지는 CI/CD에서 S3에 업로드 후 갱신
  s3_bucket = var.lambda_code_bucket
  s3_key    = "lambda/finding-enricher.zip"

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
}

# ── health-enricher ───────────────────────────────────────────────────────

resource "aws_lambda_function" "health_enricher" {
  function_name = "${local.prefix}-lmd-health-enricher"
  role          = aws_iam_role.lambda.arn
  runtime       = "python3.12"
  handler       = "health_enricher.handler"
  timeout       = 30
  memory_size   = 256

  s3_bucket = var.lambda_code_bucket
  s3_key    = "lambda/health-enricher.zip"

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
}
