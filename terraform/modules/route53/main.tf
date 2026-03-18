# ── Hosted Zone ──────────────────────────────────────────────────────────────

resource "aws_route53_zone" "main" {
  name = var.domain

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# ── A 레코드 (단일 ALB 설계) ─────────────────────────────────────────────────
# web과 api가 동일한 ALB를 공유한다. 트래픽 분기는 Ingress 호스트 기반 라우팅으로 처리.
# ALB가 분리될 경우 alb_dns_name_web / alb_dns_name_api 변수로 분리 필요.

# ── A 레코드: dndn.cloud → Web ALB ───────────────────────────────────────────

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

# ── A 레코드: api.dndn.cloud → API ALB ───────────────────────────────────────

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
