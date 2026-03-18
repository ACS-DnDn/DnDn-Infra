# Architecture

이 문서는 `DnDn-Infra`, `DnDn-App`, `DnDn-HR`를 함께 기준으로, DnDn 플랫폼의 목표 아키텍처를 정리합니다.

현재 상태와 목표 상태를 분리해서 봐야 합니다.

- 현재 상태
  - CloudFormation 기반 고객 계정 연동
  - Terraform 기반 플랫폼 공통 인프라
  - 일부 event enricher Lambda 소스
- 목표 상태
  - Terraform 기반 공통 인프라
  - EKS 기반 앱 런타임
  - Argo CD 기반 GitOps 배포
  - `DnDn-App` 및 `DnDn-HR` 워크로드의 쿠버네티스 운영

## 1. Repository Roles

### DnDn-Infra

이 레포는 아래를 관리합니다.

- AWS 계정 연동용 CloudFormation
- 플랫폼 공통 AWS 자원
- Terraform 기반 네트워크 / EKS / 공통 인프라
- 향후 Argo CD 기반 GitOps 선언
- 앱이 올라갈 런타임 환경

### DnDn-App

앱 레포는 아래를 관리합니다.

- `apps/web`
- `apps/api`
- `apps/worker`
- `apps/report`
- `contracts`

즉, `DnDn-App`은 제품 코드와 실행 로직을 관리하고, `DnDn-Infra`는 그 코드가 배포되고 운영될 환경을 관리합니다.

### DnDn-HR

`DnDn-HR`는 현재 확인 범위 기준으로 별도 프론트엔드 레포입니다.

현재 이해 기준 역할:

- 인사/조직 관리 포털
- DnDn 서비스 접근 계정 관리
- 사용자 / 부서 / 권한 관리 성격의 관리자 UI
- 별도 프론트엔드 앱으로 배포
- 백엔드는 메인 DnDn 서비스와 연동

즉, `DnDn-HR`는 메인 DnDn 서비스와 분리된 관리자용 서브 애플리케이션으로 보는 것이 자연스럽습니다.

## 2. High-Level Architecture

큰 구조는 아래 흐름입니다.

```text
Customer AWS Accounts
  -> CloudFormation onboarding
  -> EventBridge forwarding / AssumeRole
  -> DnDn Platform AWS Account
  -> Shared AWS services
     - EventBridge
     - Cognito
     - S3
     - SQS
     - RDS
     - EKS
  -> Argo CD
  -> Platform workloads on Kubernetes
     - DnDn-App / web
     - DnDn-App / api
     - DnDn-App / worker
     - DnDn-App / report
     - DnDn-HR / frontend
       -> backend integration to DnDn-App / api
```

## 3. Architecture Layers

### Layer A. Customer Account Onboarding

고객 AWS 계정에는 CloudFormation으로 아래를 배포합니다.

- `DnDnOpsAgentRole`
- 필요 시 EventBridge forwarding rule

이 레이어의 목적은 두 가지입니다.

- DnDn 플랫폼이 고객 계정 리소스를 읽을 수 있게 함
- 고객 이벤트를 플랫폼 계정으로 전달하게 함

현재 관련 자산:

- `cloudformation/dndn-ops-agent-role.yaml`

### Layer B. Platform Integration Layer

플랫폼 계정에는 고객 이벤트를 받는 통합 계층이 필요합니다.

현재는 아래가 이 역할을 합니다.

- EventBridge Bus
- CloudTrail / Config / Security Hub / Health 수신 규칙
- event enricher Lambda

현재 관련 자산:

- `terraform/modules/eventbridge`
- `lambda/event-enricher/`

이 레이어는 앱 본체보다 앞단의 “수집 입구”입니다.

### Layer C. Shared Platform Services

앱과 event enricher가 함께 의존하는 공통 서비스입니다.

- Cognito
- RDS
- S3
- SQS
- IAM / STS

현재는 Terraform으로 상당 부분 정의되어 있습니다.

- Cognito: Terraform 모듈 있음
- RDS / S3 / SQS / Lambda runtime: Terraform 모듈 있음
- EKS / IRSA / Route53 / ACM: Terraform 모듈 있음

### Layer D. Application Runtime

장기적으로 DnDn 애플리케이션은 EKS 위에서 동작합니다.

예상 배포 대상:

- `DnDn-App/web`
- `DnDn-App/api`
- `DnDn-App/worker`
- `DnDn-App/report`
- `DnDn-HR/frontend`

이 레이어는 Terraform이 만든 EKS 클러스터 위에, Argo CD가 GitOps로 배포합니다.

### Layer E. GitOps Control Plane

Argo CD는 배포 상태를 Git으로 선언적으로 관리하는 계층입니다.

예상 역할:

- 앱별 Application 관리
- 환경별 overlay 분리
- 운영자가 kubectl 수동 배포 없이 Git 변경으로 배포
- dev / staging / prod 배포 흐름 표준화

## 4. Current vs Target

### Current

현재는 아래 구조가 실제로 존재합니다.

- 고객 계정 온보딩 CloudFormation
- Terraform `prod` 환경
- platform modules
- Security Hub / AWS Health event enricher Lambda 소스
- docs

즉, 지금은 “초기 파이프라인 단계”를 지나, 플랫폼 공통 인프라를 Terraform으로 옮기고 있는 전환기입니다.

### Target

목표 구조는 아래입니다.

1. CloudFormation
   - 고객 계정 온보딩
2. Terraform
   - VPC
   - EKS
   - 공통 AWS 서비스
   - Lambda runtime
   - Cognito / EventBridge
   - 추후 Argo CD 부트스트랩
3. GitOps
   - Kubernetes app 배포 선언
4. DnDn-App
   - 컨테이너 이미지 산출
   - 애플리케이션 실행
5. DnDn-HR
   - 관리자 포털 프론트엔드 실행
   - 메인 서비스 백엔드 연동

## 5. Suggested Infra Repository Structure

현재 구조와 목표 구조를 섞어서 보면 아래처럼 가는 것이 자연스럽습니다.

```text
DnDn-Infra/
├─ cloudformation/
│  └─ dndn-ops-agent-role.yaml
├─ terraform/
│  ├─ envs/
│  │  ├─ dev/
│  │  ├─ staging/
│  │  └─ prod/
│  └─ modules/
│     ├─ vpc/
│     ├─ eks/
│     ├─ eventbridge/
│     ├─ iam_irsa/
│     ├─ s3/
│     ├─ sqs/
│     ├─ rds/
│     ├─ lambda/
│     ├─ cognito/
│     ├─ route53/
│     ├─ acm/
│     └─ argocd/
├─ gitops/                # planned
├─ lambda/
│  └─ event-enricher/
└─ docs/
```

## 6. Deployment Lanes

앞으로는 배포 레인을 두 개로 나눠 생각하는 것이 좋습니다.

### Lane 1. Bootstrap / Integration

여기에는 아래가 들어갑니다.

- 고객 계정 CloudFormation
- Terraform platform baseline
- Lambda runtime
- 초기 event enricher

이 레인은 현재 CloudFormation + Terraform 혼합입니다.

### Lane 2. Runtime / GitOps

여기에는 아래가 들어갑니다.

- VPC
- EKS
- S3 / SQS / RDS 같은 공통 런타임 자산
- Argo CD
- 앱 배포 선언

이 레인은 Terraform + GitOps 중심입니다.

## 7. Design Principles

앞으로 구조를 늘릴 때는 아래 원칙을 유지하는 것이 좋습니다.

- 인프라 자원 정의는 `DnDn-Infra`에 둔다
- 앱 실행 코드는 `DnDn-App`에 둔다
- HR 포털 코드는 `DnDn-HR`에 둔다
- HR 포털 백엔드 연동 지점은 기본적으로 `DnDn-App/api`를 우선 기준으로 본다
- Kubernetes 배포 선언은 `DnDn-Infra`에 둔다
- 데이터 계약은 `DnDn-App/contracts`를 단일 기준으로 쓴다
- 고객 계정 온보딩은 CloudFormation으로 단순하게 유지한다
- 장기 런타임은 Terraform + Argo CD로 표준화한다

## 8. Immediate Next Decisions

지금 당장 결정이 필요한 건 아래입니다.

1. `DnDn-Infra`에 Terraform 골격을 먼저 만들지
2. GitOps 디렉터리 구조를 먼저 만들지
3. env-level Terraform output을 먼저 정리할지
4. `DnDn-App/worker`를 EKS workload로 배포할지, 별도 compute로 둘지
5. `DnDn-HR`를 메인 앱과 같은 클러스터/도메인 체계에 둘지 확정할지

현재 방향성을 기준으로 보면, 아래 순서가 가장 안정적입니다.

1. 문서 정리
2. Terraform output / naming 정리
3. EKS / Argo CD 부트스트랩
4. GitOps app 선언
5. 마지막에 runtime 자산 상세화
