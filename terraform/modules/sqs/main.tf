locals {
  prefix = "${lower(var.project)}-${lower(var.environment)}"
}

# ── S3 이벤트 → Reporter 트리거 큐 ───────────────────────────────────────

resource "aws_sqs_queue" "s3_event" {
  name                       = "${local.prefix}-sqs-s3-event"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600 # 4일
  sqs_managed_sse_enabled    = true

  tags = {
    Name = "${local.prefix}-sqs-s3-event"
  }
}

# ── 이벤트보고서 생성 요청 큐 (Lambda → Reporter) ─────────────────────────

resource "aws_sqs_queue" "event_report" {
  name                       = "${local.prefix}-sqs-event-report"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 345600 # 4일
  sqs_managed_sse_enabled    = true

  tags = {
    Name = "${local.prefix}-sqs-event-report"
  }
}

# ── 현황보고서 생성 요청 큐 (API 서버 / Scheduler → Worker) ──────────────

resource "aws_sqs_queue" "report_request" {
  name                       = "${local.prefix}-sqs-report-request"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 345600 # 4일
  sqs_managed_sse_enabled    = true

  tags = {
    Name = "${local.prefix}-sqs-report-request"
  }
}
