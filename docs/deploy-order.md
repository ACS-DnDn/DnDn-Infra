# Deploy Order

이 문서는 현재 `DnDn-Infra` 저장소 기준의 배포 순서와 선행 조건을 정리합니다.

main 기준 현재 구조는 아래처럼 바뀌었습니다.

- 고객 계정 온보딩: CloudFormation
- 플랫폼 공통 인프라: Terraform
- event enricher 코드: Lambda 소스 디렉터리

즉, 현재 배포의 중심은 Terraform이고, CloudFormation은 고객 계정 온보딩 용도로 남아 있습니다.

## Deployment Overview

배포 흐름은 아래 순서로 진행하는 것이 안전합니다.

1. 플랫폼 계정 Terraform 적용
2. 고객 계정 온보딩 CloudFormation 배포
3. Lambda 코드 / 앱 아티팩트 배포
4. 이벤트 연동 및 애플리케이션 검증

핵심 원칙은 이렇습니다.

- 먼저 플랫폼 계정 공통 자원을 Terraform으로 만든다
- 그 다음 고객 계정이 플랫폼 EventBridge로 보낼 수 있게 연결한다
- Lambda 코드는 자원 생성과 별개로 배포해야 한다
- EKS 앱 배포는 Argo CD 기반 GitOps로 표준화한다

## Step 1. Platform Terraform Apply

배포 대상:

- `terraform/envs/prod`

배포 계정:

- DnDn 플랫폼 AWS 계정

목적:

- 플랫폼 공통 인프라 생성
- EventBridge / Lambda / Cognito / EKS / RDS / S3 / SQS 생성
- 앱 런타임 기반 준비

현재 `prod`에서 생성되는 주요 자산:

- VPC / Security Groups / Bastion
- ECR
- RDS
- EKS
- SQS
- S3
- Lambda
- Cognito
- EventBridge
- Route53 / ACM
- IAM IRSA

초기 적용 시 주의:

- 현재 환경은 `prod`만 존재
- Lambda 모듈은 함수 리소스를 만들지만, zip 패키지는 별도 업로드를 전제로 함
- EventBridge는 Terraform 모듈로 생성되며, Worker Lambda는 여전히 optional 상태임

주요 출력값:

- `eks_cluster_name`
- `rds_endpoint`
- `rds_secret_arn`
- `cognito_user_pool_id`
- `cognito_app_client_id`
- `report_request_queue_url`
- `s3_bucket_name`
- `irsa_*_role_arn`
- `acm_certificate_arn`

추가 확인 필요:

- 고객 CFN 입력에 필요한 `event_bus_arn`은 현재 `terraform/modules/eventbridge`에는 있으나, `terraform/envs/prod/outputs.tf`에는 아직 노출되어 있지 않습니다
- 고객 온보딩 자동화를 위해 이 출력값을 env 레벨에서도 노출하는 것이 좋습니다

## Step 2. Customer Account CloudFormation

배포 대상:

- `cloudformation/dndn-ops-agent-role.yaml`

배포 계정:

- 고객 AWS 계정

목적:

- 플랫폼 계정이 고객 계정 `DnDnOpsAgentRole`을 `AssumeRole` 할 수 있도록 설정
- 필요 시 고객 이벤트를 플랫폼 EventBus로 포워딩할 EventBridge 규칙 생성

주요 파라미터:

- `DnDnPlatformAccountId`
- `ExternalId`
- `DnDnEventBusArn`
- `EnableEventForwarding=false`

초기 배포 시 주의:

- 첫 배포는 반드시 `EnableEventForwarding=false`
- `DnDnEventBusArn`에는 Step 1 Terraform에서 생성된 EventBridge Bus ARN 사용
- `ExternalId`는 고객별 고유값이어야 함

주요 출력값:

- `RoleArn`
- `RoleName`
- `EventForwardingEnabled`
- `EventForwardRoleArn` (forwarding 활성화 시)

## Step 3. Artifact Deployment

Terraform이 자리를 만들더라도, 실제 코드와 앱은 별도 배포가 필요합니다.

현재 별도 반영이 필요한 항목:

- finding enricher Lambda zip
- health enricher Lambda zip
- `DnDn-App` 이미지 빌드 및 푸시
- `DnDn-HR` 프론트엔드 이미지 또는 정적 배포 산출물 반영
- GitOps 설정 변경 반영

현재 상태:

- Lambda 런타임 자원은 Terraform에 있음
- Lambda 코드 반영 파이프라인은 별도 유지
- GitOps Application 리소스는 추가되었으나, 실제 워크로드(Deployment/Service 등)는 placeholder만 존재
- Worker Lambda는 여전히 별도 구현 또는 전략 결정이 필요함

### Recommended CD Model

앱 배포 기준 권장 모델은 아래와 같습니다.

1. GitHub Actions가 이미지 빌드
2. ECR에 이미지 푸시
3. GitOps 선언의 이미지 태그 또는 values 갱신
4. Argo CD가 변경을 감지해 EKS에 반영

즉, 장기 기준 CD는 `helm 직접 배포`보다 `Argo CD 동기화`가 중심입니다.

### Required Environment Variables

현재 Lambda 코드 기준으로 필요한 주요 환경변수는 아래와 같습니다.

- `DB_HOST`
- `DB_PORT`
- `DB_NAME`
- `DB_USER`
- `DB_PASSWORD`
- `REPORT_QUEUE_URL`
- `OUTPUT_BUCKET`
- `CUSTOMER_ROLE_NAME`
- `ASSUME_ROLE_EXTERNAL_ID`

참고:

- `CUSTOMER_ROLE_NAME` 기본값은 `DnDnOpsAgentRole`
- 고객별 `external_id`는 DB `workspaces.external_id`에서 조회
- 기본 `ASSUME_ROLE_EXTERNAL_ID`는 fallback 성격

### Required External Resources

- MariaDB
  - `workspaces.acct_id`
  - `workspaces.external_id`
  - `report_settings.event_settings`
- SQS
  - 보고서 생성 요청 큐
- S3
  - raw / enriched 결과 저장 버킷

### Current Gap

현재 레포 기준으로 가장 큰 공백은 여기입니다.

- Lambda 패키징 / 배포 파이프라인 부재
- EKS 앱 배포 구조는 추가되었으나 실제 워크로드 매니페스트는 아직 미구현
- 앱별 Argo CD Application은 있으나 실제 워크로드 매니페스트는 placeholder 상태
- Worker Lambda 부재

즉, 이제는 런타임 "자원 정의"보다 "배포 자동화와 운영 레인 정리"가 더 큰 과제입니다.

## Step 4. Customer Event Forwarding Enable

고객 계정 온보딩이 끝나고 플랫폼 EventBridge ARN이 연결된 뒤, 고객 스택에서 forwarding을 켭니다.

업데이트 대상:

- `cloudformation/dndn-ops-agent-role.yaml`

변경 파라미터:

- `EnableEventForwarding=true`

이때부터 고객 계정 이벤트가 플랫폼 EventBus로 실제 유입됩니다.

## Step 5. Verification

배포 후에는 아래 순서로 검증합니다.

### 1. Platform Stack Verification

- Terraform 리소스가 정상 생성되었는지 확인
- EventBridge Bus와 수신 규칙이 생성되었는지 확인
- EKS / RDS / S3 / SQS / Cognito 출력값이 정상인지 확인

### 2. Customer Stack Verification

- 고객 계정에 `DnDnOpsAgentRole`이 생성되었는지 확인
- 플랫폼 계정에서 `AssumeRole` 가능한지 확인
- forwarding 활성화 후 EventBridge rule이 ENABLED 상태인지 확인

### 3. Lambda Verification

- Security Hub 이벤트가 `finding_enricher`를 호출하는지 확인
- AWS Health 이벤트가 `health_enricher`를 호출하는지 확인
- Lambda가 DB 연결에 성공하는지 확인
- Lambda가 S3에 결과를 저장하는지 확인
- Lambda가 SQS에 보고서 요청을 넣는지 확인

### 4. End-to-End Verification

- 고객 계정에서 테스트 이벤트 발생
- 플랫폼 EventBus 수신 확인
- Lambda 실행 확인
- S3 raw / enriched 결과 확인
- SQS 메시지 확인

## Recommended Next Work

현재 시점에서 추천 우선순위는 아래와 같습니다.

1. `docs/deploy-order.md` 유지 및 보완
2. Terraform 출력값 / 운영 흐름 정리
3. GitOps 디렉터리 구조 추가
4. Worker Lambda 처리 방향 확정
5. 검증 절차와 운영 체크리스트 문서화

## Next Implementation Tasks

바로 이어서 작업한다면 아래 순서가 가장 자연스럽습니다.

### Priority 1. Terraform Output Cleanup

정리할 것:

- 고객 CFN에 필요한 EventBridge ARN env 출력
- 운영에 필요한 핵심 출력값 점검
- naming / environment 표준화

### Priority 2. GitOps Skeleton

추가할 것:

- `gitops/bootstrap`
- `gitops/apps`
- `gitops/environments`

### Priority 3. Worker Strategy

결정 필요:

- Worker Lambda를 바로 구현할지
- CloudTrail / Config는 당분간 로그 적재만 할지
- 플랫폼 EventBus 템플릿을 Worker optional 구조로 바꿀지

현재는 Worker가 빠져 있어서 전체 플로우가 완전히 닫히지 않습니다.

### Priority 4. CI/CD and Ops Docs

추가 문서 후보:

- `docs/configuration.md`
- `docs/verification.md`
- `docs/customer-onboarding.md`
- Lambda / image 배포 파이프라인 문서

## Practical Recommendation

지금 가장 좋은 다음 액션은 아래 둘 중 하나입니다.

1. Terraform 출력값과 GitOps 골격부터 정리해서 운영 레인을 명확히 하기
2. 그 다음 `Worker Lambda`를 당장 만들지 여부를 결정하기

실무적으로는 1번부터 가고, Worker는 임시 제외 또는 optional 처리하는 방향이 가장 빠릅니다.
