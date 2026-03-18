locals {
  # worker Lambda 미배포 시 로그 그룹으로 fallback
  cloudtrail_target_arn = var.worker_lambda_arn != "" ? var.worker_lambda_arn : aws_cloudwatch_log_group.events.arn
  config_target_arn     = var.worker_lambda_arn != "" ? var.worker_lambda_arn : aws_cloudwatch_log_group.events.arn
}

# ── EventBus ──────────────────────────────────────────────────────────────

resource "aws_cloudwatch_event_bus" "main" {
  name = "dndn-ops-events"

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# 크로스 계정 수신 허용 정책
resource "aws_cloudwatch_event_bus_policy" "cross_account" {
  event_bus_name = aws_cloudwatch_event_bus.main.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowCustomerAccounts"
      Effect = "Allow"
      Principal = {
        AWS = formatlist("arn:aws:iam::%s:root", var.allowed_account_ids)
      }
      Action   = "events:PutEvents"
      Resource = aws_cloudwatch_event_bus.main.arn
    }]
  })
}

# ── CloudWatch Log Group (Lambda 미연동 시 이벤트 로깅용) ─────────────────

resource "aws_cloudwatch_log_group" "events" {
  name              = "/dndn/ops-events"
  retention_in_days = 30

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_resource_policy" "eventbridge" {
  policy_name = "DnDnEventBusToLogs"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource  = "${aws_cloudwatch_log_group.events.arn}:*"
    }]
  })
}

# ── 수신 규칙: CloudTrail → Worker Lambda ─────────────────────────────────

resource "aws_cloudwatch_event_rule" "cloudtrail" {
  name           = "DnDn-Receive-CloudTrail"
  description    = "고객 계정에서 포워딩된 CloudTrail 변경 이벤트 처리"
  event_bus_name = aws_cloudwatch_event_bus.main.name
  state          = "ENABLED"

  event_pattern = jsonencode({
    source = [
      "aws.ec2", "aws.rds", "aws.s3", "aws.lambda",
      "aws.ecs", "aws.eks", "aws.elasticloadbalancing",
      "aws.autoscaling", "aws.iam", "aws.cloudformation"
    ]
    "detail-type" = ["AWS API Call via CloudTrail"]
  })
}

resource "aws_cloudwatch_event_target" "cloudtrail" {
  rule           = aws_cloudwatch_event_rule.cloudtrail.name
  event_bus_name = aws_cloudwatch_event_bus.main.name
  target_id      = var.worker_lambda_arn != "" ? "WorkerLambda" : "LogOnly"
  arn            = local.cloudtrail_target_arn
}

# ── 수신 규칙: Config → Worker Lambda ────────────────────────────────────

resource "aws_cloudwatch_event_rule" "config" {
  name           = "DnDn-Receive-Config"
  description    = "고객 계정에서 포워딩된 Config 변경 처리"
  event_bus_name = aws_cloudwatch_event_bus.main.name
  state          = "ENABLED"

  event_pattern = jsonencode({
    source        = ["aws.config"]
    "detail-type" = ["Config Rules Compliance Change", "Config Configuration Item Change"]
  })
}

resource "aws_cloudwatch_event_target" "config" {
  rule           = aws_cloudwatch_event_rule.config.name
  event_bus_name = aws_cloudwatch_event_bus.main.name
  target_id      = var.worker_lambda_arn != "" ? "WorkerLambda" : "LogOnly"
  arn            = local.config_target_arn
}

# ── 수신 규칙: SecurityHub → Finding Enricher ─────────────────────────────

resource "aws_cloudwatch_event_rule" "securityhub" {
  name           = "DnDn-Receive-SecurityHub"
  description    = "고객 계정에서 포워딩된 Security Hub finding → 이벤트 보고서 생성"
  event_bus_name = aws_cloudwatch_event_bus.main.name
  state          = "ENABLED"

  event_pattern = jsonencode({
    source        = ["aws.securityhub"]
    "detail-type" = ["Security Hub Findings - Imported", "Security Hub Findings - Custom Action"]
  })
}

resource "aws_cloudwatch_event_target" "securityhub" {
  rule           = aws_cloudwatch_event_rule.securityhub.name
  event_bus_name = aws_cloudwatch_event_bus.main.name
  target_id      = "FindingEnricher"
  arn            = var.finding_enricher_arn
}

# ── 수신 규칙: Health → Health Enricher ──────────────────────────────────

resource "aws_cloudwatch_event_rule" "health" {
  name           = "DnDn-Receive-Health"
  description    = "고객 계정에서 포워딩된 AWS Health 이벤트 → 이벤트 보고서 생성"
  event_bus_name = aws_cloudwatch_event_bus.main.name
  state          = "ENABLED"

  event_pattern = jsonencode({
    source        = ["aws.health"]
    "detail-type" = ["AWS Health Event"]
  })
}

resource "aws_cloudwatch_event_target" "health" {
  rule           = aws_cloudwatch_event_rule.health.name
  event_bus_name = aws_cloudwatch_event_bus.main.name
  target_id      = "HealthEnricher"
  arn            = var.health_enricher_arn
}

# ── Lambda 실행 권한 (EventBridge → Lambda) ───────────────────────────────

resource "aws_lambda_permission" "securityhub" {
  statement_id  = "AllowEventBridgeSecurityHub"
  action        = "lambda:InvokeFunction"
  function_name = var.finding_enricher_arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.securityhub.arn
}

resource "aws_lambda_permission" "health" {
  statement_id  = "AllowEventBridgeHealth"
  action        = "lambda:InvokeFunction"
  function_name = var.health_enricher_arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.health.arn
}

resource "aws_lambda_permission" "cloudtrail_worker" {
  count = var.worker_lambda_arn != "" ? 1 : 0

  statement_id  = "AllowEventBridgeCloudTrail"
  action        = "lambda:InvokeFunction"
  function_name = var.worker_lambda_arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cloudtrail.arn
}

resource "aws_lambda_permission" "config_worker" {
  count = var.worker_lambda_arn != "" ? 1 : 0

  statement_id  = "AllowEventBridgeConfig"
  action        = "lambda:InvokeFunction"
  function_name = var.worker_lambda_arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.config.arn
}

# ── Worker AssumeRole 정책 ────────────────────────────────────────────────

resource "aws_iam_policy" "worker_assume" {
  name        = "DnDnWorker-AssumeCustomerRoles"
  description = "Worker/Lambda가 고객 계정의 DnDnOpsAgentRole을 AssumeRole"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "AssumeCustomerRoles"
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = "arn:aws:iam::*:role/DnDnOpsAgentRole"
      Condition = {
        "ForAnyValue:StringEquals" = {
          "aws:ResourceAccount" = var.allowed_account_ids
        }
      }
    }]
  })
}
