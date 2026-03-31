# Deploy Order

이 문서는 현재 `DnDn-Infra` 기준의 실제 배포 순서를 정리합니다.

## Deployment Overview

현재 안전한 순서는 아래입니다.

1. 플랫폼 계정 Terraform 적용
2. CloudFormation 템플릿 업로드 및 고객 계정 온보딩
3. Lambda 코드 배포
4. Argo CD root / child app 상태 확인
5. 앱 이미지 반영
6. 운영 검증

핵심 원칙은 아래와 같습니다.

- AWS 공통 자원이 먼저 준비되어야 한다
- 고객 계정은 플랫폼 EventBridge ARN을 받은 뒤 연결한다
- Lambda 코드는 Terraform과 별도로 배포한다
- 앱 이미지는 Git manifest와 클러스터 둘 다 현재 워크플로우가 반영한다

## Step 1. Platform Terraform Apply

대상:

- `terraform/envs/prod`

목적:

- 플랫폼 공통 AWS 자원 생성
- EKS / RDS / S3 / SQS / EventBridge / Lambda / Cognito / Route53 / ACM / IRSA 준비

현재 주요 출력값:

- `eks_cluster_name`
- `rds_endpoint`
- `rds_secret_arn`
- `cognito_user_pool_id`
- `cognito_app_client_id`
- `report_request_queue_url`
- `s3_bucket_name`
- `event_bus_arn`
- `scheduler_role_arn`
- `scheduler_group_name`
- `scheduler_trigger_lambda_arn`
- `irsa_*_role_arn`
- `acm_certificate_arn`
- `acm_hr_certificate_arn`

운영 메모:

- 현재 환경 엔트리는 `prod`만 존재
- Lambda 모듈은 더미 zip으로 함수 리소스를 먼저 만들고, 실제 코드는 후속 워크플로우가 덮어쓴다

## Step 2. CloudFormation Upload And Customer Onboarding

대상:

- 업로드: `.github/workflows/deploy-cfn.yml`
- 템플릿: `cloudformation/dndn-ops-agent-role.yaml`

목적:

- 고객 계정에 `DnDnOpsAgentRole` 배포
- 필요 시 고객 이벤트를 플랫폼 EventBridge로 전달

초기 파라미터 기준:

- `DnDnPlatformAccountId`
- `ExternalId`
- `DnDnEventBusArn`
- `EnableEventForwarding=false`

주의:

- 첫 배포는 `EnableEventForwarding=false`
- `DnDnEventBusArn`에는 Terraform output `event_bus_arn` 사용

## Step 3. Lambda Code Deployment

대상 워크플로우:

- `.github/workflows/deploy-lambda.yml`

현재 배포되는 함수:

- `dndn-prd-lmd-finding-enricher`
- `dndn-prd-lmd-health-enricher`
- `dndn-prd-lmd-scheduler-trigger`

구현 메모:

- `event-enricher`는 의존성을 함께 패키징
- `scheduler-trigger`는 `handler.py` 단일 파일 zip
- 업로드 대상 S3 키는 `lambda/<name>.zip`

## Step 4. Argo CD Bootstrap And Base Sync

초기 진입점:

```bash
kubectl apply -f gitops/bootstrap/root-app-prod.yaml -n argocd
```

이후 기준 경로:

- root source: `gitops/environments/prod/root`
- child apps: `gitops/environments/prod/apps/*`

현재 root source에 포함된 핵심 요소:

- `platform` AppProject
- `dndn-external-secrets`
- `ClusterSecretStore/aws-secretsmanager`
- `dndn-api`
- `dndn-web`
- `dndn-worker`
- `dndn-report`
- `dndn-hr`
- `dndn-monitoring`
- `argocd` ingress

## Step 5. Application Image Rollout

현재 앱 이미지 반영은 아래처럼 동작합니다.

1. 앱 레포가 ECR에 이미지 푸시
2. `repository_dispatch`가 이 레포의 `.github/workflows/update-image.yml` 트리거
3. 워크플로우가 `gitops/environments/prod/apps/<app>/deployment.yaml`의 `image:`를 갱신 후 커밋
4. 같은 워크플로우가 Bastion에서 `kubectl set image`로 즉시 롤아웃

주의:

- 현재 prod는 Argo CD만으로 배포가 끝나는 구조가 아니다
- `dndn-report`는 `dndn-report-api`, `dndn-report-worker` 두 Deployment를 동시에 갱신한다

## Step 6. Verification

배포 후 최소 검증 순서는 아래입니다.

### Platform

- Terraform 리소스 생성 여부
- EventBridge bus / rules
- EKS / RDS / S3 / SQS / Cognito 출력값

### Customer Onboarding

- 고객 계정 `DnDnOpsAgentRole`
- 플랫폼 계정 `AssumeRole`
- forwarding 활성화 후 EventBridge rule 상태

### Lambda

- `finding_enricher`, `health_enricher` 호출
- DB / S3 / SQS 연동
- `scheduler-trigger`의 내부 API 호출 성공

### EKS / GitOps

- `dndn-prod-root`, child app sync / health
- `dndn-api`, `dndn-report`, `dndn-worker` pod 상태
- 필요한 경우 Bastion 롤아웃 직후와 Argo CD reconcile 이후 상태 비교

## Current Gaps

아직 남아 있는 운영 과제는 아래입니다.

- monitoring 스택 본체 설치 경로 / values / ownership
- pure Argo CD 배포로 정리할지 여부
- `dev`, `staging` 환경 전략
