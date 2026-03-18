# DnDn-Infra

DnDn 플랫폼의 AWS 연동용 인프라 자산을 관리하는 저장소입니다.

현재 이 레포의 범위는 크게 두 가지입니다.

1. 고객 AWS 계정과 DnDn 플랫폼 계정의 연결
2. 수신 이벤트를 정규화하고 보고서 생성을 트리거하는 Lambda 코드

`terraform/`, `docs/`, `scripts/`, `.github/` 같은 런타임/운영 보강 영역은 아직 이 저장소에 포함되어 있지 않습니다.

## Current Scope

현재 포함된 자산은 아래 두 디렉터리가 전부입니다.

```text
DnDn-Infra/
├─ README.md
├─ .gitignore
├─ cloudformation/
│  ├─ cognito-userpool.yaml
│  ├─ dndn-ops-agent-role.yaml
│  └─ dndn-platform-eventbus.yaml
└─ lambda/
   └─ event-enricher/
      ├─ event_router.py
      ├─ finding_enricher.py
      ├─ health_enricher.py
      └─ requirements.txt
```

## What This Repo Does

### 1. Customer Account Integration

고객 계정에는 `cloudformation/dndn-ops-agent-role.yaml`을 배포합니다.

- `DnDnOpsAgentRole` 생성
- 플랫폼 계정이 `sts:AssumeRole`로 접근 가능하도록 설정
- CloudTrail, Config, Security Hub, Cost Explorer, CloudWatch, 기본 리소스 조회 권한 부여
- 선택적으로 EventBridge 규칙을 통해 고객 계정 이벤트를 플랫폼 EventBus로 전달

### 2. Platform Event Ingestion

플랫폼 계정에는 `cloudformation/dndn-platform-eventbus.yaml`을 배포합니다.

- 크로스 계정 수신용 EventBridge Bus 생성
- 고객 계정 ID 허용 정책 설정
- CloudTrail, Config, Security Hub, AWS Health 이벤트 수신 규칙 생성
- Lambda가 아직 없을 때는 CloudWatch Logs로 기록
- Lambda 배포 후에는 각 이벤트를 Worker/Finding/Health Lambda로 전달

### 3. Cognito Bootstrap

`cloudformation/cognito-userpool.yaml`은 앱 인증 초기 구성을 담당합니다.

- 이메일 기반 Cognito User Pool
- AdminCreateUser 전용 사용자 생성
- Secret 없는 App Client
- `hr`, `leader`, `member` 그룹 생성

### 4. Event Enrichment

`lambda/event-enricher/`는 수신 이벤트를 정규화하고 보고서 생성을 트리거합니다.

- `event_router.py`
  - MariaDB에서 `workspace_id`, `event_settings`, `external_id` 조회
  - 고객 계정 `AssumeRole` 세션 생성
  - SQS로 보고서 생성 요청 전달
- `finding_enricher.py`
  - Security Hub finding을 `event_key`로 매핑
  - 리소스별 추가 정보 수집
  - canonical JSON 생성 후 S3 저장
  - SQS로 보고서 생성 트리거
- `health_enricher.py`
  - AWS Health 이벤트를 `event_key`로 매핑
  - Health API 상세/영향 리소스 조회
  - canonical JSON 생성 후 S3 저장
  - SQS로 보고서 생성 트리거

## Deployment Shape

현재 코드 기준 배포 흐름은 아래 순서입니다.

1. 플랫폼 계정에 `dndn-platform-eventbus.yaml` 배포
2. 생성된 `EventBusArn`을 고객 계정 배포 파라미터로 사용
3. 고객 계정에 `dndn-ops-agent-role.yaml` 배포
4. Lambda, S3, SQS, DB 연결 환경변수 등 런타임 자산 배포
5. 플랫폼 EventBus 스택에서 `EnableLambdaTrigger=true`로 갱신
6. 고객 계정 스택에서 `EnableEventForwarding=true`로 갱신

즉, 현재 CloudFormation 템플릿은 "계정 연결"과 "이벤트 라우팅"의 골격을 제공하고, Lambda 실행 인프라 자체는 아직 이 레포에 정의되어 있지 않습니다.

## Runtime Dependencies

Lambda 코드는 아래 외부 리소스에 의존합니다.

- MariaDB
  - `workspaces.acct_id`
  - `workspaces.external_id`
  - `report_settings.event_settings`
- SQS
  - 보고서 생성 요청 전달용 큐
- S3
  - raw/enriched 이벤트 JSON 저장 버킷
- IAM / STS
  - 고객 계정 `DnDnOpsAgentRole` AssumeRole

필수 환경변수 예시는 아래와 같습니다.

- `DB_HOST`
- `DB_PORT`
- `DB_NAME`
- `DB_USER`
- `DB_PASSWORD`
- `REPORT_QUEUE_URL`
- `OUTPUT_BUCKET`
- `CUSTOMER_ROLE_NAME`
- `ASSUME_ROLE_EXTERNAL_ID`

## Current Gaps

이 레포에는 아직 아래 항목이 없습니다.

- Lambda 배포용 CloudFormation/SAM/Terraform
- Lambda 실행 IAM Role 정의
- S3 버킷, SQS 큐 생성 템플릿
- CI/CD 워크플로우
- 운영 문서와 배포 스크립트
- Worker Lambda 소스 코드

따라서 현재 상태는 "완성된 전체 인프라 레포"라기보다, DnDn의 AWS 계정 연동 파이프라인을 먼저 분리해 둔 초기 인프라 레포로 보는 게 맞습니다.

## Next Recommended Structure

추후 이 레포를 확장한다면, 현재 코드와 가장 직접적으로 이어지는 영역은 아래 정도입니다.

- `docs/`
  - 배포 순서
  - 계정 연동 가이드
  - 이벤트 처리 아키텍처
- `terraform/`
  - Lambda, S3, SQS 같은 런타임 자산
- `scripts/`
  - 패키징 및 배포 보조 스크립트
- `.github/workflows/`
  - lint, package, deploy 자동화
