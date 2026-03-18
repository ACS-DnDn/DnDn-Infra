# ── dndn.cloud Hosted Zone ────────────────────────────────────────────────

resource "aws_route53_zone" "main" {
  name = var.domain

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# ── dndnhr.cloud Hosted Zone ──────────────────────────────────────────────

resource "aws_route53_zone" "hr" {
  name = var.hr_domain

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# ── A 레코드: dndn.cloud / www.dndn.cloud / api.dndn.cloud → ALB ──────────
# 단일 ALB, Ingress 호스트 기반 라우팅으로 트래픽 분기

resource "aws_route53_record" "web" {
  count = var.alb_dns_name != "" ? 1 : 0

  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_hosted_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "web_www" {
  count = var.alb_dns_name != "" ? 1 : 0

  zone_id = aws_route53_zone.main.zone_id
  name    = "www.${var.domain}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_hosted_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "api" {
  count = var.alb_dns_name != "" ? 1 : 0

  zone_id = aws_route53_zone.main.zone_id
  name    = "api.${var.domain}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_hosted_zone_id
    evaluate_target_health = true
  }
}

# ── A 레코드: dndnhr.cloud / www.dndnhr.cloud → 동일 ALB ─────────────────

resource "aws_route53_record" "hr_web" {
  count = var.alb_dns_name != "" ? 1 : 0

  zone_id = aws_route53_zone.hr.zone_id
  name    = var.hr_domain
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_hosted_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "hr_web_www" {
  count = var.alb_dns_name != "" ? 1 : 0

  zone_id = aws_route53_zone.hr.zone_id
  name    = "www.${var.hr_domain}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_hosted_zone_id
    evaluate_target_health = true
  }
}
