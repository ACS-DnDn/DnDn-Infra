locals {
  prefix      = "${lower(var.project)}-${lower(var.environment)}"
  bucket_name = "${local.prefix}-s3"
}

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

# ── S3 이벤트 알림 (canonical/ PUT → SQS) ────────────────────────────────

resource "aws_s3_bucket_notification" "main" {
  bucket = aws_s3_bucket.main.id

  queue {
    queue_arn     = var.s3_event_queue_arn
    events        = ["s3:ObjectCreated:Put"]
    filter_prefix = "canonical/"
    filter_suffix = ".json"
  }
}
