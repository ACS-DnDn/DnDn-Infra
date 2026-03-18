locals {
  prefix           = "${lower(var.project)}-${lower(var.environment)}"
  bucket_name      = "${local.prefix}-s3"
  # ARN → URL: arn:aws:sqs:REGION:ACCOUNT:NAME → https://sqs.REGION.amazonaws.com/ACCOUNT/NAME
  queue_name       = element(split(":", var.s3_event_queue_arn), 5)
  s3_event_queue_url = "https://sqs.${data.aws_region.current.name}.amazonaws.com/${data.aws_caller_identity.current.account_id}/${local.queue_name}"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ── S3 버킷 ───────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "main" {
  bucket = local.bucket_name

  tags = {
    Name = local.bucket_name
  }
}

# ── 퍼블릭 접근 차단 ──────────────────────────────────────────────────────

resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── 서버 사이드 암호화 (SSE-S3) ───────────────────────────────────────────

resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ── Lifecycle (canonical/ 30일 후 자동 삭제) ─────────────────────────────

resource "aws_s3_bucket_lifecycle_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    id     = "expire-canonical"
    status = "Enabled"

    filter {
      prefix = "canonical/"
    }

    expiration {
      days = 30
    }
  }
}

# ── SQS 큐 정책 (S3 → SQS SendMessage 허용) ─────────────────────────────
# S3 이벤트 알림이 SQS에 메시지를 보내려면 큐 정책이 명시적으로 허용해야 함

resource "aws_sqs_queue_policy" "s3_event" {
  queue_url = local.s3_event_queue_url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = var.s3_event_queue_arn
      Condition = {
        ArnLike = {
          "aws:SourceArn" = aws_s3_bucket.main.arn
        }
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })
}

# ── S3 이벤트 알림 (canonical/ PUT → SQS) ────────────────────────────────

resource "aws_s3_bucket_notification" "main" {
  bucket     = aws_s3_bucket.main.id
  depends_on = [aws_sqs_queue_policy.s3_event]

  queue {
    queue_arn     = var.s3_event_queue_arn
    events        = ["s3:ObjectCreated:Put"]
    filter_prefix = "canonical/"
    filter_suffix = ".json"
  }
}
