locals {
  prefix = "${lower(var.project)}-${lower(var.environment)}"

  repositories = [
    "web",
    "hr",
    "api",
    "worker",
    "report",
  ]
}

resource "aws_ecr_repository" "this" {
  for_each = toset(local.repositories)

  name                 = "${local.prefix}-${each.key}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${local.prefix}-${each.key}"
  }
}

# ── 이미지 수명 주기 정책 (최근 30개만 보관) ─────────────────────────────

resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 30 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 30
      }
      action = {
        type = "expire"
      }
    }]
  })
}
