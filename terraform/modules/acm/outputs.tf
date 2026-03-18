output "certificate_arn" {
  description = "ACM 인증서 ARN (ALB Ingress annotation에 사용)"
  value       = aws_acm_certificate_validation.main.certificate_arn
}
