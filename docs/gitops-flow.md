# GitOps Flow

이 문서는 DnDn의 현재 GitOps 운영 흐름을 "실제 구현 기준"으로 정리합니다.

## Core Flow

현재 prod 이미지 반영 흐름은 아래 한 줄로 요약할 수 있습니다.

`앱 레포 이미지 푸시 -> Infra 레포 manifest 이미지 갱신 커밋 -> Bastion 즉시 롤아웃 -> Argo CD reconcile`

핵심 원칙은 아래 두 가지입니다.

- Git manifest가 배포 기준 상태다
- 즉시 롤아웃은 현재 워크플로우가 보조 수행한다

즉 현재는 "순수 Argo-only"가 아니라 GitOps와 직접 롤아웃이 같이 있는 하이브리드 상태입니다.

## Ownership In The Flow

| Area | Owner | Responsibility |
| --- | --- | --- |
| 애플리케이션 코드 | `DnDn-App`, `DnDn-HR` | 코드 변경, 이미지 빌드, ECR 푸시 |
| 인프라 / GitOps 구조 | `DnDn-Infra` | Terraform, Argo CD, 환경별 manifest |
| 이미지 태그 반영 | `DnDn-Infra` workflow | deployment manifest image 갱신과 커밋 |
| 즉시 롤아웃 | `DnDn-Infra` workflow | Bastion 경유 `kubectl set image` |
| 지속적 정합성 유지 | Argo CD | Git 상태 기준 reconcile |

## Current Image Update Path

현재 구현된 이미지 반영 절차는 아래와 같습니다.

1. 앱 레포가 이미지를 빌드하고 ECR에 푸시
2. 앱 레포가 `repository_dispatch`로 이 레포의 `update-image.yml`을 트리거
3. `update-image.yml`이 `gitops/environments/prod/apps/<app>/deployment.yaml`의 `image:`를 교체
4. 워크플로우가 변경을 `main`에 커밋 / 푸시
5. 같은 워크플로우가 Bastion에서 `kubectl set image`를 실행해 즉시 배포
6. Argo CD가 커밋된 Git 상태와 클러스터 상태를 이후 계속 맞춤

예외 케이스:

- `dndn-report`
  - 하나의 이미지 태그를 `dndn-report-api`, `dndn-report-worker` 두 Deployment에 함께 반영

## Argo CD Shape

현재 GitOps 구조는 `app-of-apps`입니다.

- bootstrap: `gitops/bootstrap/root-app-prod.yaml`
- root source: `gitops/environments/prod/root`
- child apps: `gitops/environments/prod/root/*-app.yaml`
- shared copy: `gitops/apps/*.yaml`
- project: `gitops/projects/platform.yaml`

중요한 운영 메모:

- `dndn-prod-root`가 직접 읽는 경로는 `gitops/environments/prod/root/*`
- `prod/root`는 Argo CD kustomize path restriction 때문에 self-contained source로 유지
- `gitops/apps/*.yaml`는 child app 정의의 공유 위치이지만, bootstrap 기준점은 root source
- `dndn-external-secrets`와 `ClusterSecretStore`는 root source에서 함께 관리
- `dndn-monitoring`은 현재 `ServiceMonitor` 리소스만 관리

## Current Prod Scope

현재 prod child app 범위는 아래입니다.

- `dndn-api`
- `dndn-web`
- `dndn-worker`
- `dndn-report`
- `dndn-hr`
- `dndn-monitoring`
- `dndn-external-secrets`

현재 secret 주입 구조는 아래가 기준입니다.

- `dndn-api`, `dndn-report`
  - AWS Secrets Manager + External Secrets Operator
- `dndn-web`, `dndn-hr`, `dndn-worker`
  - 현재 prod manifest 기준 별도 Kubernetes Secret 없음

## Known Gaps

현재 GitOps 구조에서 아직 남아 있는 과제는 아래입니다.

- `dev`, `staging` 환경 부재
- monitoring 스택 본체 설치 경로 / values / ownership 미정리
- Argo CD repo credential 선언 부재
- direct rollout 없이 Argo CD만으로 운영할지 여부 미정리
