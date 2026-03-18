locals {
  prefix   = "${var.project}-${var.environment}"
  oidc_url = replace(var.oidc_provider_url, "https://", "")
  region   = data.aws_region.current.name
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ── GitHub Actions OIDC Provider ──────────────────────────────────────────

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
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
        # GetAuthorizationToken은 서비스 레벨 작업 — Resource = "*" 필수
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
        ]
        Resource = "arn:aws:ecr:${local.region}:${data.aws_caller_identity.current.account_id}:repository/${local.prefix}-*"
      },
      {
        Effect   = "Allow"
        Action   = ["lambda:UpdateFunctionCode", "lambda:GetFunction"]
        Resource = "arn:aws:lambda:${local.region}:${data.aws_caller_identity.current.account_id}:function:${local.prefix}-lmd-*"
      },
      {
        Effect   = "Allow"
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${var.s3_bucket_name}/lambda/*"
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

resource "aws_scheduler_schedule_group" "dndn_schedules" {
  name = "dndn-schedules"

  tags = {
    Project     = var.project
    Environment = var.environment
  }
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
          "scheduler:ListSchedules",
        ]
        Resource = "${aws_scheduler_schedule_group.dndn_schedules.arn}/*"
      },
      {
        # create_schedule / update_schedule 호출 시 Target.RoleArn 전달 필요
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.scheduler.arn
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

resource "aws_iam_role_policy" "worker_sqs" {
  name = "SQSConsumePolicy"
  role = aws_iam_role.worker.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
      ]
      Resource = var.report_request_queue_arn
    }]
  })
}

resource "aws_iam_role_policy" "worker_s3" {
  name = "S3WorkerPolicy"
  role = aws_iam_role.worker.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject", "s3:GetObject"]
      Resource = "arn:aws:s3:::${var.s3_bucket_name}/reports/*"
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

resource "aws_iam_role_policy" "reporter_bedrock" {
  name = "BedrockInvokePolicy"
  role = aws_iam_role.reporter.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream",
      ]
      Resource = "arn:aws:bedrock:${local.region}::foundation-model/*"
    }]
  })
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

resource "aws_iam_role_policy" "reporter_sqs" {
  name = "SQSConsumePolicy"
  role = aws_iam_role.reporter.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
      ]
      Resource = var.s3_event_queue_arn
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
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
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
