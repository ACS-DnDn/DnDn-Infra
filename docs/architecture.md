# Architecture

이 문서는 DnDn 인프라의 "현재 구현 상태"를 기준으로 전체 구조를 정리합니다.

## Repository Roles

현재 세 레포의 역할은 아래처럼 보면 됩니다.

- `DnDn-Infra`
  - 고객 온보딩 CloudFormation
  - 플랫폼 공통 AWS 인프라 Terraform
  - Lambda 소스와 배포 워크플로우
  - Argo CD / GitOps 선언과 운영 문서
- `DnDn-App`
  - 메인 서비스 코드
  - `web`, `api`, `worker`, `report`, `contracts`
  - 이미지 빌드와 푸시
- `DnDn-HR`
  - HR 포털 프론트엔드 코드
  - 이미지 빌드와 푸시

즉 앱 레포는 실행 산출물을 만들고, 이 레포는 그 산출물이 올라갈 AWS / Kubernetes 런타임과 배포 경로를 관리합니다.

## High-Level Shape

현재 구조를 한 줄로 요약하면 아래와 같습니다.

`고객 계정 온보딩 -> 플랫폼 AWS 공통 자원 -> Lambda + EKS 런타임 -> GitOps + 운영 워크플로우`

큰 흐름은 아래와 같습니다.

```text
Customer AWS Accounts
  -> CloudFormation onboarding
  -> AssumeRole / EventBridge forwarding

DnDn Platform AWS Account
  -> Terraform-managed shared services
     - VPC / Security Groups / Bastion
     - ECR / EKS / IAM IRSA
     - RDS / S3 / SQS
     - Cognito / EventBridge / Route53 / ACM
     - Lambda runtime

Operational Workloads
  -> event-enricher Lambdas
  -> scheduler-trigger Lambda
  -> Argo CD
  -> EKS workloads
     - dndn-web
     - dndn-api
     - dndn-worker
     - dndn-report-api
     - dndn-report-worker
     - dndn-hr
```

## Implemented Layers

### 1. Customer Onboarding

고객 계정에는 `cloudformation/dndn-ops-agent-role.yaml`을 배포합니다.

이 스택은 아래를 담당합니다.

- `DnDnOpsAgentRole`
- 플랫폼 계정의 `AssumeRole`
- 플랫폼 EventBridge로의 이벤트 전달

### 2. Shared AWS Infrastructure

플랫폼 계정의 공통 인프라는 `terraform/envs/prod`가 기준입니다.

현재 prod에서 실제로 조립되는 모듈:

- `vpc`
- `security_groups`
- `bastion`
- `ecr`
- `rds`
- `eks`
- `sqs`
- `s3`
- `lambda`
- `cognito`
- `eventbridge`
- `route53`
- `acm`
- `iam_irsa`
- `app_secrets`
- `alb_controller`
- `s3_public`

### 3. Lambda Runtime

현재 이 레포에는 두 종류의 Lambda 소스가 있습니다.

- `lambda/event-enricher`
  - `finding_enricher`
  - `health_enricher`
  - `event_router`
- `lambda/scheduler-trigger`
  - EventBridge Scheduler에서 API `/reports/summary` 호출

Terraform은 이 함수들의 런타임 리소스를 만들고, 실제 코드는 GitHub Actions가 `aws lambda update-function-code`로 반영합니다.

### 4. EKS Application Runtime

현재 GitOps manifest 기준 prod 워크로드는 아래입니다.

- `dndn-web`
- `dndn-api`
- `dndn-worker`
- `dndn-report-api`
- `dndn-report-worker`
- `dndn-hr`

추가로 monitoring 영역에는 아래가 선언되어 있습니다.

- `dndn-monitoring`
  - `dndn-api`, `dndn-report`, `dndn-worker`용 `ServiceMonitor`

주의할 점은, 이 레포가 관리하는 monitoring 범위는 `ServiceMonitor`뿐이고, 실제 kube-prometheus-stack 설치 경로와 values는 아직 이 레포에서 완전히 선언되지 않았다는 점입니다.

### 5. GitOps Control Plane

Argo CD는 `app-of-apps` 구조로 운영됩니다.

- bootstrap entry: `gitops/bootstrap/root-app-prod.yaml`
- root source: `gitops/environments/prod/root`
- child apps: `gitops/environments/prod/apps/*`
- shared project: `gitops/projects/platform.yaml`

또한 아래 운영 요소도 root source에 함께 들어 있습니다.

- `dndn-external-secrets`
- `ClusterSecretStore/aws-secretsmanager`
- `argocd` ingress

## Current Deployment Reality

문서상 목표와 달리, 현재 앱 배포는 완전한 Argo-only 흐름은 아닙니다.

현재 prod 이미지 반영 순서는 아래와 같습니다.

1. 앱 레포가 이미지를 빌드해 ECR에 푸시
2. `update-image.yml`이 이 레포의 manifest 이미지를 갱신하고 커밋
3. 같은 워크플로우가 Bastion을 통해 `kubectl set image`로 즉시 롤아웃
4. Argo CD가 이후 Git 상태를 기준으로 계속 reconcile

즉 현재는 Git이 기준선이지만, 롤아웃 방식은 GitOps와 직접 `kubectl`이 같이 존재하는 하이브리드 구조입니다.

## Known Gaps

현재 구조에서 아직 덜 닫힌 부분은 아래입니다.

- `dev`, `staging` 환경 부재
- monitoring 설치 경로 / values / ownership 미정리
- Argo CD repo credential 선언 부재
- event enricher 확장 전략과 후속 worker 방향
