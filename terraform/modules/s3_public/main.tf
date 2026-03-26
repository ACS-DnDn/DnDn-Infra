data "aws_region" "current" {}

locals {
  bucket_name = "dndn-public"
}

# ── S3 퍼블릭 버킷 (고객 배포용 CFN 템플릿 + 회사 로고) ──────────────────

resource "aws_s3_bucket" "public" {
  bucket = local.bucket_name

  tags = {
    Name      = local.bucket_name
    ManagedBy = "Terraform"
  }
}

# ── 퍼블릭 접근 설정 ──────────────────────────────────────────────────────
# cfn/, logos/ 경로만 퍼블릭 읽기 허용 → BlockPublicPolicy/RestrictPublicBuckets = false

resource "aws_s3_bucket_public_access_block" "public" {
  bucket = aws_s3_bucket.public.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = false
  restrict_public_buckets = false
}

# ── 버킷 정책 (cfn/, logos/ 퍼블릭 읽기) ─────────────────────────────────

resource "aws_s3_bucket_policy" "public" {
  bucket     = aws_s3_bucket.public.id
  depends_on = [aws_s3_bucket_public_access_block.public]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyNonTLS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.public.arn,
          "${aws_s3_bucket.public.arn}/*",
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid       = "PublicReadCfnTemplates"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.public.arn}/cfn/*"
      },
      {
        Sid       = "PublicReadLogos"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.public.arn}/logos/*"
      },
    ]
  })
}

# ── SSE 암호화 ────────────────────────────────────────────────────────────

resource "aws_s3_bucket_server_side_encryption_configuration" "public" {
  bucket = aws_s3_bucket.public.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
