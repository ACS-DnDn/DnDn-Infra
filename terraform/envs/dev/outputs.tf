# ── Cognito ──────────────────────────────────────────────────────────────

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID — API 환경변수 COGNITO_USER_POOL_ID에 사용"
  value       = module.cognito.user_pool_id
}

output "cognito_app_client_id" {
  description = "Cognito App Client ID — API 환경변수 COGNITO_CLIENT_ID에 사용"
  value       = module.cognito.app_client_id
}

# ── EC2 ──────────────────────────────────────────────────────────────────

output "ec2_instance_id" {
  description = "DEV EC2 인스턴스 ID"
  value       = module.ec2.instance_id
}

output "ec2_public_ip" {
  description = "DEV EC2 공인 IP — SSH 접속 및 브라우저 접근"
  value       = module.ec2.public_ip
}

output "ec2_private_ip" {
  description = "DEV EC2 사설 IP — Lambda API_INTERNAL_URL (http://{ip}:8000)"
  value       = module.ec2.private_ip
}

# ── SQS ──────────────────────────────────────────────────────────────────

output "report_request_queue_url" {
  description = "보고서 요청 큐 URL — API 환경변수 DNDN_QUEUE_URL에 사용"
  value       = module.sqs.report_request_queue_url
}

# ── S3 ───────────────────────────────────────────────────────────────────

output "s3_public_bucket_name" {
  description = "퍼블릭 자산 버킷 이름 (DEV/PRD 공유) — CFN 템플릿 업로드 대상"
  value       = data.aws_s3_bucket.public.id
}

output "s3_public_cfn_base_url" {
  description = "고객 배포용 CFN base URL (DEV/PRD 공유)"
  value       = "https://${data.aws_s3_bucket.public.bucket}.s3.${data.aws_s3_bucket.public.region}.amazonaws.com/cfn"
}

output "s3_bucket_name" {
  description = "S3 버킷 이름 — Lambda 환경변수 OUTPUT_BUCKET에 사용"
  value       = module.s3.bucket_name
}

# ── DB ────────────────────────────────────────────────────────────────────

output "dev_db_secret_arn" {
  description = "DEV MariaDB 자격증명 Secret ARN — Lambda 환경변수 RDS_SECRET_ARN에 사용"
  value       = aws_secretsmanager_secret.dev_db.arn
}

# ── EventBridge Scheduler ─────────────────────────────────────────────────

output "scheduler_role_arn" {
  description = "EventBridge Scheduler 실행 Role ARN — API 환경변수 SCHEDULER_ROLE_ARN에 사용"
  value       = aws_iam_role.scheduler.arn
}

output "scheduler_group_name" {
  description = "EventBridge Scheduler 그룹 이름 — API 환경변수 SCHEDULER_GROUP_NAME에 사용"
  value       = aws_scheduler_schedule_group.dndn_schedules.name
}

output "scheduler_trigger_lambda_arn" {
  description = "scheduler-trigger Lambda ARN — API 환경변수 SCHEDULER_TARGET_ARN에 사용"
  value       = module.lambda.scheduler_trigger_arn
}
