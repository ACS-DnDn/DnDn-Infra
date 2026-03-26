locals {
  prefix = "${lower(var.project)}-${lower(var.environment)}"
}

# ── API 시크릿 (/dndn/prod/api) ──────────────────────────────────────────
# K8s ExternalSecrets → ClusterSecretStore → 이 시크릿 참조
# 값은 수동으로 설정 (Terraform은 뼈대만 생성)

resource "aws_secretsmanager_secret" "api" {
  name        = "/dndn/${lower(var.environment == "PRD" ? "prod" : var.environment)}/api"
  description = "dndn-api pod용 — DB 연결, OAuth 자격증명, internal key, webhook secret"

  tags = {
    Name      = "${local.prefix}-API-SECRET"
    ManagedBy = "Terraform"
  }
}

resource "aws_secretsmanager_secret_version" "api" {
  secret_id = aws_secretsmanager_secret.api.id

  secret_string = jsonencode({
    SQLALCHEMY_DATABASE_URL = var.api_database_url
    STS_EXTERNAL_ID         = var.sts_external_id
    INTERNAL_API_KEY        = var.internal_api_key
    GITHUB_CLIENT_ID        = var.github_client_id
    GITHUB_CLIENT_SECRET    = var.github_client_secret
    SLACK_CLIENT_ID         = var.slack_client_id
    SLACK_CLIENT_SECRET     = var.slack_client_secret
    GITHUB_WEBHOOK_SECRET   = var.github_webhook_secret
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# ── Report 시크릿 (/dndn/prod/report) ────────────────────────────────────

resource "aws_secretsmanager_secret" "report" {
  name        = "/dndn/${lower(var.environment == "PRD" ? "prod" : var.environment)}/report"
  description = "dndn-report pod용 — DB 연결, internal key"

  tags = {
    Name      = "${local.prefix}-REPORT-SECRET"
    ManagedBy = "Terraform"
  }
}

resource "aws_secretsmanager_secret_version" "report" {
  secret_id = aws_secretsmanager_secret.report.id

  secret_string = jsonencode({
    DATABASE_URL     = var.report_database_url
    INTERNAL_API_KEY = var.internal_api_key
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}
