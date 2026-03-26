# ── EKS ──────────────────────────────────────────────────────────────────────

output "eks_cluster_name" {
  description = "EKS 클러스터 이름 (kubectl config에 사용)"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS API 서버 엔드포인트"
  value       = module.eks.cluster_endpoint
}

# ── RDS ──────────────────────────────────────────────────────────────────────

output "rds_endpoint" {
  description = "RDS 엔드포인트 (host:port) — Helm values DB_HOST에 사용"
  value       = module.rds.endpoint
}

output "rds_secret_arn" {
  description = "RDS 마스터 계정 Secret ARN — Lambda 환경변수 RDS_SECRET_ARN에 사용"
  value       = module.rds.master_user_secret_arn
}

# ── Cognito ───────────────────────────────────────────────────────────────────

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID — API 환경변수 COGNITO_USER_POOL_ID에 사용"
  value       = module.cognito.user_pool_id
}

output "cognito_app_client_id" {
  description = "Cognito App Client ID — API 환경변수 COGNITO_CLIENT_ID에 사용"
  value       = module.cognito.app_client_id
}

# ── SQS ──────────────────────────────────────────────────────────────────────

output "report_request_queue_url" {
  description = "현황보고서 요청 큐 URL — Worker 환경변수 DNDN_WORKER_QUEUE_URL에 사용"
  value       = module.sqs.report_request_queue_url
}

# ── S3 ───────────────────────────────────────────────────────────────────────

output "s3_bucket_name" {
  description = "S3 버킷 이름 — Lambda 환경변수 OUTPUT_BUCKET에 사용"
  value       = module.s3.bucket_name
}

# ── EventBridge Scheduler ─────────────────────────────────────────────────────

output "scheduler_role_arn" {
  description = "EventBridge Scheduler 실행 Role ARN — API 환경변수 SCHEDULER_ROLE_ARN에 사용"
  value       = module.iam_irsa.scheduler_role_arn
}

output "scheduler_group_name" {
  description = "EventBridge Scheduler 그룹 이름 — API 환경변수 SCHEDULER_GROUP_NAME에 사용"
  value       = module.iam_irsa.scheduler_group_name
}

output "scheduler_trigger_lambda_arn" {
  description = "scheduler-trigger Lambda ARN — API 환경변수 SCHEDULER_TARGET_ARN에 사용"
  value       = module.lambda.scheduler_trigger_arn
}

# ── IRSA Role ARNs ────────────────────────────────────────────────────────────

output "irsa_api_role_arn" {
  description = "API ServiceAccount IRSA Role ARN — Helm values serviceAccount.annotations에 사용"
  value       = module.iam_irsa.api_role_arn
}

output "irsa_worker_role_arn" {
  description = "Worker ServiceAccount IRSA Role ARN — Helm values serviceAccount.annotations에 사용"
  value       = module.iam_irsa.worker_role_arn
}

output "irsa_reporter_role_arn" {
  description = "Reporter ServiceAccount IRSA Role ARN — Helm values serviceAccount.annotations에 사용"
  value       = module.iam_irsa.reporter_role_arn
}

output "irsa_external_secrets_role_arn" {
  description = "External Secrets ServiceAccount IRSA Role ARN"
  value       = module.iam_irsa.external_secrets_role_arn
}

# ── ACM ───────────────────────────────────────────────────────────────────────

output "acm_certificate_arn" {
  description = "dndn.cloud ACM 인증서 ARN — ALB Ingress annotation에 사용"
  value       = module.acm.certificate_arn
}

output "acm_hr_certificate_arn" {
  description = "dndnhr.cloud ACM 인증서 ARN — ALB Ingress annotation에 사용"
  value       = module.acm.hr_certificate_arn
}

# ── S3 Public ─────────────────────────────────────────────────────────────────

output "s3_public_bucket_name" {
  description = "퍼블릭 자산 버킷 이름 — CFN 템플릿 업로드 대상"
  value       = data.aws_s3_bucket.public.id
}

output "s3_public_cfn_base_url" {
  description = "고객 배포용 CFN base URL — 온보딩 플로우에서 Launch Stack URL 생성에 사용"
  value       = "https://${data.aws_s3_bucket.public.bucket}.s3.${data.aws_s3_bucket.public.region}.amazonaws.com/cfn"
}

# ── Route53 ───────────────────────────────────────────────────────────────────

output "route53_name_servers" {
  description = "dndn.cloud NS 레코드 — 도메인 등록기관에 입력 필요"
  value       = module.route53.name_servers
}

output "route53_hr_name_servers" {
  description = "dndnhr.cloud NS 레코드 — 도메인 등록기관에 입력 필요"
  value       = module.route53.hr_name_servers
}
