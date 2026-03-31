# DnDn-Infra

DnDn 플랫폼의 AWS 인프라, Lambda, GitOps, 운영 문서를 관리하는 저장소입니다.

현재 이 레포가 실제로 맡는 범위는 아래 네 축입니다.

1. 고객 AWS 계정 온보딩용 CloudFormation
2. 플랫폼 AWS 공통 인프라용 Terraform
3. 운영 Lambda 소스와 배포 워크플로우
4. EKS 앱 배포용 Argo CD / GitOps 선언

## Current Implementation

현재 저장소 기준으로 이미 구현된 상태는 아래 정도로 보면 충분합니다.

- `cloudformation/dndn-ops-agent-role.yaml`
  - 고객 계정 온보딩 스택
- `terraform/envs/prod`
  - 현재 유일한 실제 환경 엔트리
- `lambda/event-enricher`
  - event enricher Lambda 소스
- `lambda/scheduler-trigger`
  - Scheduler bridge Lambda
- `gitops/environments/prod`
  - prod 앱 manifest와 root source

관련 애플리케이션 레포의 책임은 아래처럼 나뉩니다.

- `DnDn-App`
  - `web`, `api`, `worker`, `report`, `contracts`
  - Docker image 빌드와 ECR 푸시
- `DnDn-HR`
  - HR 포털 프론트엔드 이미지 빌드와 ECR 푸시
- `DnDn-Infra`
  - 인프라 생성, 배포 선언, 운영 절차, 환경별 설정

## Deployment Shape

현재 구현 기준 배포 흐름은 아래입니다.

1. `terraform/envs/prod`로 플랫폼 공통 자원 생성
2. `cloudformation/` 템플릿을 S3에 업로드하고 고객 계정에 온보딩 스택 배포
3. `deploy-lambda.yml`로 `finding-enricher`, `health-enricher`, `scheduler-trigger` 코드 배포
4. 앱 레포가 이미지를 빌드해 ECR에 푸시
5. 이 레포의 `update-image.yml`이 `gitops/environments/prod/apps/*/deployment.yaml` 이미지를 갱신하고 커밋
6. Argo CD가 Git 상태를 감지해 rollout
7. 운영자는 Argo CD health / sync 상태만 확인

즉 현재 앱 CD는 Git manifest 갱신 후 Argo CD가 반영하는 pure GitOps 경로를 기준으로 합니다. 자세한 구조와 운영 원칙은 아래 문서를 봅니다.

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

아직 문서에 남겨둘 정도로 큰 미해결 과제는 아래 2가지입니다.

- `dev`, `staging` 환경의 실제 생성 시점
- private repo 전환 시 실제 credential cutover 시점

## Docs

현재는 아래 문서만 보면 됩니다.

- [docs/architecture.md](docs/architecture.md)
  - 전체 구조, 레포 책임, 워크로드 기준
- [docs/operations-runbook.md](docs/operations-runbook.md)
  - 배포 순서, GitOps 흐름, 운영 점검
- [gitops/environments/prod/README.md](gitops/environments/prod/README.md)
  - prod 디렉터리 로컬 안내
