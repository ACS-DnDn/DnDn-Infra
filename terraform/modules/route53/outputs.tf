output "zone_id" {
  description = "Route53 Hosted Zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "name_servers" {
  description = "NS 레코드 — 도메인 등록 기관에 입력 필요"
  value       = aws_route53_zone.main.name_servers
}
