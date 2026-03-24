output "endpoint" {
  description = "RDS 엔드포인트 (host:port)"
  value       = aws_db_instance.main.endpoint
}

output "master_user_secret_arn" {
  description = "Secrets Manager에 저장된 RDS 마스터 계정 Secret ARN"
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
}

output "app_secret_arn" {
  description = "Lambda용 DB 연결 정보 Secret ARN (host/port/username/password/dbname 포함)"
  value       = aws_secretsmanager_secret.app_db.arn
}
