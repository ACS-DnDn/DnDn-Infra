# DnDn-Infra

DnDn 플랫폼의 AWS 인프라와 배포 기반을 관리하는 저장소입니다.

현재 이 레포는 두 레인을 함께 다룹니다.

1. 고객 AWS 계정 온보딩
2. 플랫폼 공통 인프라와 애플리케이션 런타임 기반

즉, 지금은 초기 CloudFormation만 있는 레포가 아니라, `CloudFormation + Terraform + GitOps`가 함께 운영되는 전환기 구조입니다.

플랫폼 애플리케이션 관점에서는 현재 최소 아래 레포들을 함께 봐야 합니다.

- `DnDn-App`
  - 메인 DnDn 서비스
  - `web`, `api`, `worker`, `report`, `contracts`
- `DnDn-HR`
  - 인사/조직/계정 관리용 별도 포털
  - 별도 프론트엔드 앱으로 배포
  - 백엔드는 메인 서비스와 연동
  - DnDn 서비스 접근 계정과 부서/사용자 관리 성격으로 이해하는 것이 자연스럽습니다

현재 기준 책임 분리는 아래처럼 보는 것이 맞습니다.

- `DnDn-App`, `DnDn-HR`
  - 애플리케이션 코드 소유
  - Docker image 빌드 및 ECR 푸시
- `DnDn-Infra`
  - Terraform, Helm/Kustomize, GitOps, Argo CD 배포 선언 소유
  - 환경별 values / secret / ingress / runtime 설정 소유

## Current Scope

현재 실제 포함된 주요 구조는 아래와 같습니다.

```text
DnDn-Infra/
├─ README.md
├─ .github/
│  └─ workflows/
│     ├─ deploy-lambda.yml
│     └─ terraform.yml
├─ cloudformation/
│  └─ dndn-ops-agent-role.yaml
├─ lambda/
│  └─ event-enricher/
│     ├─ event_router.py
│     ├─ finding_enricher.py
│     ├─ health_enricher.py
│     └─ requirements.txt
├─ terraform/
│  ├─ envs/
│  │  └─ prod/
│  └─ modules/
│     ├─ acm/
│     ├─ bastion/
│     ├─ cognito/
│     ├─ ecr/
│     ├─ eks/
│     ├─ eventbridge/
│     ├─ iam_irsa/
│     ├─ lambda/
│     ├─ rds/
│     ├─ route53/
│     ├─ s3/
│     ├─ security_groups/
│     ├─ sqs/
│     └─ vpc/
├─ docs/
│  ├─ architecture.md
│  ├─ deploy-order.md
│  ├─ deployment-requirements.md
│  ├─ gitops-flow.md
│  ├─ repo-boundaries.md
│  └─ workload-mapping.md
└─ gitops/
   ├─ README.md
   ├─ projects/
   │  └─ platform.yaml
   ├─ bootstrap/
   │  └─ root-app-prod.yaml
   ├─ apps/
   │  ├─ dndn-api.yaml
   │  ├─ dndn-hr.yaml
   │  ├─ dndn-report.yaml
   │  ├─ dndn-web.yaml
   │  └─ dndn-worker.yaml
   └─ environments/
      └─ prod/
         ├─ apps/ ... manifest
         ├─ ingress/
         ├─ root/ ... root app source
         └─ README.md
```

아직 없는 영역:

- `terraform/envs/dev`, `terraform/envs/staging`

현재 이미 포함된 자동화:

- `.github/workflows/terraform.yml`
- `.github/workflows/deploy-lambda.yml`

## What This Repo Does

### 1. Customer Account Onboarding

`cloudformation/dndn-ops-agent-role.yaml`은 고객 AWS 계정에 배포하는 스택입니다.

- `DnDnOpsAgentRole` 생성
- 플랫폼 계정이 `sts:AssumeRole` 할 수 있도록 설정
- 고객 이벤트를 플랫폼 EventBridge로 포워딩할 규칙 생성 가능

### 2. Platform Runtime Infrastructure

`terraform/envs/prod/`는 현재 플랫폼 공통 인프라의 실제 배포 엔트리입니다.

현재 `prod`에서 조합되는 주요 모듈:

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

즉, 플랫폼 계정의 공통 AWS 자원은 이미 Terraform 중심으로 넘어온 상태입니다.

이 인프라는 장기적으로 `DnDn-App`과 `DnDn-HR` 둘 다 올라갈 공통 런타임 기반으로 보는 것이 맞습니다.

### 3. Event Enricher Lambda Source

`lambda/event-enricher/`는 EventBridge에 연결되는 Lambda 소스 코드입니다.

- `finding_enricher.py`
- `health_enricher.py`
- `event_router.py`

이 코드는 아래 리소스에 의존합니다.

- RDS / MariaDB
- SQS
- S3
- IAM / STS

Terraform의 `lambda` 모듈이 이 함수들의 런타임 자리를 만들고, 코드 배포 패키지는 별도 업로드 흐름을 전제로 합니다.

### 4. GitOps Foundation

`gitops/`는 Argo CD 기반 GitOps 운영 선언을 담습니다.

현재 포함된 것:

- `AppProject`
- 앱별 child application
- `prod` bootstrap root app
- `prod/root` self-contained source
- `prod` 환경 앱 manifest
- `prod` 공용 ingress manifest

현재 포함되지 않은 것:

- bootstrap 이후 운영 runbook과 검증 기준 문서

## Deployment Shape

현재 기준 배포 흐름은 아래 순서로 보는 것이 맞습니다.

1. 플랫폼 계정에 `terraform/envs/prod` 적용
2. Terraform으로 EventBridge, Lambda, Cognito, EKS, RDS, S3, SQS 같은 공통 자원 생성
3. 필요한 출력값을 기준으로 고객 계정에 `cloudformation/dndn-ops-agent-role.yaml` 배포
4. Lambda zip / 앱 이미지 / EKS 워크로드를 별도 배포 파이프라인으로 반영
5. GitHub Actions는 이미지 빌드와 푸시를 담당
6. Argo CD가 GitOps 선언을 기준으로 EKS 앱 배포를 반영

여기서 앱 워크로드는 현재 기준으로 아래를 포함할 수 있습니다.

- `DnDn-App`의 `web`, `api`, `worker`, `report-api`, `report-worker`
- `DnDn-HR` 프론트엔드

참고:

- `report-api`와 `report-worker`는 동일한 `DnDn-App/apps/report` 이미지 태그를 공유합니다
- `DnDn-App`, `DnDn-HR`의 GitHub Actions는 이미지 빌드와 푸시까지만 담당합니다
- 실제 EKS 반영은 `DnDn-Infra`의 GitOps 선언과 Argo CD가 담당합니다

즉, 현재는 고객 온보딩만 CloudFormation이고, 플랫폼 인프라는 Terraform이 중심입니다.
앱 CD의 목표 구조는 `helm 직접 배포`가 아니라 `Argo CD + Helm/Kustomize 기반 GitOps`입니다.

## Current Gaps

아직 정리가 필요한 항목은 아래와 같습니다.

- Argo CD 운영 runbook과 검증 절차 문서화
- `dev`, `staging` Terraform 환경
- 이미지 태그를 GitOps에 반영하는 전체 CD 흐름 정리
- secret 관리 방식 고도화
- Worker Lambda 또는 CloudTrail / Config 처리 전략 확정
- 고객 CFN 배포에 필요한 EventBridge 출력값 노출 방식 정리

## Related Docs

- [docs/README.md](docs/README.md)
- [docs/architecture.md](docs/architecture.md)
- [docs/repo-boundaries.md](docs/repo-boundaries.md)
- [docs/deploy-order.md](docs/deploy-order.md)
- [docs/gitops-flow.md](docs/gitops-flow.md)
- [docs/deployment-requirements.md](docs/deployment-requirements.md)
- [docs/workload-mapping.md](docs/workload-mapping.md)
- [docs/monitoring-plan.md](docs/monitoring-plan.md)
- [gitops/README.md](gitops/README.md)
