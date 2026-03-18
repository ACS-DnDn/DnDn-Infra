output "zone_id" {
  description = "dndn.cloud Route53 Hosted Zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "name_servers" {
  description = "dndn.cloud NS 레코드 — 도메인 등록 기관에 입력 필요"
  value       = aws_route53_zone.main.name_servers
}

output "hr_zone_id" {
  description = "dndnhr.cloud Route53 Hosted Zone ID"
  value       = aws_route53_zone.hr.zone_id
}

output "hr_name_servers" {
  description = "dndnhr.cloud NS 레코드 — 도메인 등록 기관에 입력 필요"
  value       = aws_route53_zone.hr.name_servers
}
