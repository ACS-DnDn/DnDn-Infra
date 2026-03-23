output "certificate_arn" {
  description = "dndn.cloud ACM 인증서 ARN (ALB Ingress annotation에 사용)"
  value       = aws_acm_certificate_validation.main.certificate_arn
}

output "hr_certificate_arn" {
  description = "dndnhr.cloud ACM 인증서 ARN (ALB Ingress annotation에 사용)"
  value       = aws_acm_certificate_validation.hr.certificate_arn
}
