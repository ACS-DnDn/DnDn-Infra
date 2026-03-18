locals {
  prefix   = "${var.project}-${var.environment}"
  oidc_url = replace(var.oidc_provider_url, "https://", "")
}

data "aws_caller_identity" "current" {}

# ── GitHub Actions OIDC Provider ──────────────────────────────────────────

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}

# GHA Terraform Role — dndn-infra 레포에서 plan/apply
resource "aws_iam_role" "gha_terraform" {
  name = "${local.prefix}-GHA-Terraform-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/DnDn-Infra:*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "gha_terraform_admin" {
  role       = aws_iam_role.gha_terraform.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# GHA Deploy Role — dndn-app 레포에서 ECR·Lambda·EKS 배포
resource "aws_iam_role" "gha_deploy" {
  name = "${local.prefix}-GHA-Deploy-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/*:*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "gha_deploy" {
  name = "GHADeployPolicy"
  role = aws_iam_role.gha_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["lambda:UpdateFunctionCode", "lambda:GetFunction"]
        Resource = "arn:aws:lambda:ap-northeast-2:${data.aws_caller_identity.current.account_id}:function:dndn-prd-lmd-*"
      },
      {
        Effect   = "Allow"
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::dndn-prd-s3/lambda/*"
      },
      {
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster", "eks:ListClusters"]
        Resource = "*"
      }
    ]
  })
}

# ── API Role (EventBridge Scheduler 관리) ─────────────────────────────────

resource "aws_iam_role" "api" {
  name = "${local.prefix}-API-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_url}:sub" = "system:serviceaccount:dndn-api:dndn-api-sa"
          "${local.oidc_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "api_scheduler" {
  name = "EventBridgeSchedulerPolicy"
  role = aws_iam_role.api.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "scheduler:CreateSchedule",
          "scheduler:UpdateSchedule",
          "scheduler:DeleteSchedule",
          "scheduler:GetSchedule",
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "sqs:SendMessage"
        Resource = var.report_request_queue_arn
      }
    ]
  })
}

# ── Worker Role (고객 계정 AssumeRole) ────────────────────────────────────

resource "aws_iam_role" "worker" {
  name = "${local.prefix}-Worker-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_url}:sub" = "system:serviceaccount:dndn-worker:dndn-worker-sa"
          "${local.oidc_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "worker_assume" {
  name = "AssumeCustomerAgentRolePolicy"
  role = aws_iam_role.worker.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = "arn:aws:iam::*:role/DnDnOpsAgentRole"
    }]
  })
}

# ── Reporter Role (Bedrock + S3) ──────────────────────────────────────────

resource "aws_iam_role" "reporter" {
  name = "${local.prefix}-Reporter-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_url}:sub" = "system:serviceaccount:dndn-report:dndn-reporter-sa"
          "${local.oidc_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "reporter_bedrock" {
  role       = aws_iam_role.reporter.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonBedrockFullAccess"
}

resource "aws_iam_role_policy" "reporter_s3" {
  name = "S3ReportsPolicy"
  role = aws_iam_role.reporter.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject", "s3:GetObject"]
      Resource = "arn:aws:s3:::${var.s3_bucket_name}/reports/*"
    }]
  })
}

# ── EventBridge Scheduler 실행 Role (Scheduler → SQS) ────────────────────

resource "aws_iam_role" "scheduler" {
  name = "${local.prefix}-EBS-SchedulerRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "scheduler_sqs" {
  name = "SQSSendMessagePolicy"
  role = aws_iam_role.scheduler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sqs:SendMessage"
      Resource = var.report_request_queue_arn
    }]
  })
}
