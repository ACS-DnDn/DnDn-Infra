# ── ACM 인증서 (dndn.cloud) ───────────────────────────────────────────────────
# dndn.cloud + *.dndn.cloud (와일드카드) — DNS 검증 방식

resource "aws_acm_certificate" "main" {
  domain_name               = var.domain
  subject_alternative_names = ["*.${var.domain}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# ── DNS 검증 레코드 (Route53 자동 생성) ───────────────────────────────────────

resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  allow_overwrite = true
  zone_id         = var.route53_zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
}

# ── 검증 완료 대기 ────────────────────────────────────────────────────────────

resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for r in aws_route53_record.acm_validation : r.fqdn]
}

# ── ACM 인증서 (dndnhr.cloud) ─────────────────────────────────────────────────
# dndnhr.cloud + www.dndnhr.cloud — DNS 검증 방식

resource "aws_acm_certificate" "hr" {
  domain_name               = var.hr_domain
  subject_alternative_names = ["www.${var.hr_domain}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_route53_record" "acm_validation_hr" {
  for_each = {
    for dvo in aws_acm_certificate.hr.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  allow_overwrite = true
  zone_id         = var.hr_route53_zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
}

resource "aws_acm_certificate_validation" "hr" {
  certificate_arn         = aws_acm_certificate.hr.arn
  validation_record_fqdns = [for r in aws_route53_record.acm_validation_hr : r.fqdn]
}
