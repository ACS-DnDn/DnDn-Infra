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
  description = "앱 런타임용 DB 연결 정보 Secret ARN — Lambda 환경변수 RDS_SECRET_ARN에 사용"
  value       = module.rds.app_secret_arn
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

# ── EventBridge ───────────────────────────────────────────────────────────────

output "event_bus_arn" {
  description = "플랫폼 EventBridge Bus ARN — 고객 CFN 파라미터 DnDnEventBusArn에 사용"
  value       = module.eventbridge.event_bus_arn
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
  value       = module.s3_public.bucket_name
}

output "s3_public_cfn_base_url" {
  description = "고객 배포용 CFN base URL — 온보딩 플로우에서 Launch Stack URL 생성에 사용"
  value       = module.s3_public.cfn_base_url
}

# ── App Secrets ──────────────────────────────────────────────────────────────

output "app_secret_api_arn" {
  description = "API pod ExternalSecrets 참조 Secret ARN"
  value       = module.app_secrets.api_secret_arn
}

output "app_secret_report_arn" {
  description = "Report pod ExternalSecrets 참조 Secret ARN"
  value       = module.app_secrets.report_secret_arn
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
