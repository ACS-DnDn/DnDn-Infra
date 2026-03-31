# DnDn-Infra

DnDn 플랫폼의 AWS 인프라, Lambda, GitOps, 운영 문서를 관리하는 저장소입니다.

현재 이 레포가 실제로 맡는 범위는 아래 네 축입니다.

1. 고객 AWS 계정 온보딩용 CloudFormation
2. 플랫폼 AWS 공통 인프라용 Terraform
3. 운영 Lambda 소스와 배포 워크플로우
4. EKS 앱 배포용 Argo CD / GitOps 선언

## Current Implementation

현재 저장소 기준으로 이미 구현된 상태는 아래와 같습니다.

- `cloudformation/dndn-ops-agent-role.yaml`
  - 고객 계정 `DnDnOpsAgentRole`
  - 플랫폼 EventBridge로의 forwarding 연결
- `terraform/envs/prod`
  - 현재 유일한 실제 환경 엔트리
  - `vpc`, `security_groups`, `bastion`, `ecr`, `rds`, `eks`, `sqs`, `s3`, `lambda`, `cognito`, `eventbridge`, `route53`, `acm`, `iam_irsa`, `app_secrets`, `alb_controller`, `s3_public`
- `lambda/event-enricher`
  - `finding_enricher`, `health_enricher`, `event_router`
- `lambda/scheduler-trigger`
  - EventBridge Scheduler가 내부 API를 호출하도록 연결하는 브릿지 Lambda
- `gitops/environments/prod`
  - `dndn-api`, `dndn-web`, `dndn-worker`, `dndn-report`, `dndn-hr`
  - `dndn-monitoring` child app이 관리하는 `ServiceMonitor`
  - External Secrets Operator + `ClusterSecretStore`
  - `prod/root` self-contained root source

관련 애플리케이션 레포의 책임은 아래처럼 나뉩니다.

- `DnDn-App`
  - `web`, `api`, `worker`, `report`, `contracts`
  - Docker image 빌드와 ECR 푸시
- `DnDn-HR`
  - HR 포털 프론트엔드 이미지 빌드와 ECR 푸시
- `DnDn-Infra`
  - 인프라 생성, 배포 선언, 운영 절차, 환경별 설정

## Deployment Shape

현재 구현 기준 실제 배포 흐름은 아래 순서입니다.

1. `terraform/envs/prod`로 플랫폼 공통 자원 생성
2. `cloudformation/` 템플릿을 S3에 업로드하고 고객 계정에 온보딩 스택 배포
3. `deploy-lambda.yml`로 `finding-enricher`, `health-enricher`, `scheduler-trigger` 코드 배포
4. 앱 레포가 이미지를 빌드해 ECR에 푸시
5. 이 레포의 `update-image.yml`이 `gitops/environments/prod/apps/*/deployment.yaml` 이미지를 갱신하고 커밋
6. 같은 워크플로우가 Bastion 경유 `kubectl set image`로 즉시 롤아웃
7. 이후 Argo CD가 Git 상태를 계속 기준선으로 유지

즉 현재 앱 CD는 "순수 Argo-only"가 아니라, GitOps 선언 업데이트와 Bastion 직접 롤아웃이 함께 있는 하이브리드 상태입니다.

## Key Paths

유지보수 시 자주 보는 경로는 아래 정도면 충분합니다.

- `cloudformation/`
- `terraform/envs/prod/`
- `terraform/modules/`
- `lambda/event-enricher/`
- `lambda/scheduler-trigger/`
- `gitops/bootstrap/`
- `gitops/apps/`
- `gitops/environments/prod/`
- `.github/workflows/`
- `docs/`

## Current Gaps

아직 구현 또는 문서화가 덜 끝난 항목은 아래입니다.

- `dev`, `staging` 환경 부재
- monitoring 스택 설치 경로 / values / ownership 불명확
- Argo CD repo credential 선언 부재
- EventBridge event enricher 확장 범위와 후속 worker 전략

## Docs

현재는 아래 문서만 보면 됩니다.

- [docs/architecture.md](docs/architecture.md)
  - 전체 구조, 레포 책임, 워크로드 기준
- [docs/operations-runbook.md](docs/operations-runbook.md)
  - 배포 순서, GitOps 흐름, 운영 점검
- [gitops/environments/prod/README.md](gitops/environments/prod/README.md)
  - prod GitOps 경로와 현재 manifest 범위
