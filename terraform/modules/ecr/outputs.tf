output "repository_urls" {
  description = "ECR 레포지토리 URL 맵 (key: 레포명)"
  value       = { for k, v in aws_ecr_repository.this : k => v.repository_url }
}
