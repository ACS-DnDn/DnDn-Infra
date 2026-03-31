# Workload Mapping

이 문서는 `DnDn-App`, `DnDn-HR`를 EKS와 Argo CD 기준으로 어떤 배포 단위로 보고 있는지 정리합니다.

현재 기준 운영 원칙은 아래와 같습니다.

- 배포 단위는 런타임 책임 기준으로 나눈다
- 앱 레포는 이미지 산출물을 만든다
- Git manifest가 배포 기준 상태가 된다
- 현재 prod 이미지 반영은 Infra 워크플로우가 manifest 갱신 + Bastion 롤아웃까지 수행하고, 이후 Argo CD가 상태를 유지한다

## Deployment Units

현재 기준 배포 단위는 아래 6개입니다.

| Workload | Source Repo | Runtime | Exposure | Primary Role |
| --- | --- | --- | --- | --- |
| `dndn-web` | `DnDn-App/apps/web` | `Deployment` | `Ingress` | 메인 사용자 웹 |
| `dndn-api` | `DnDn-App/apps/api` | `Deployment` | `ClusterIP` + `Ingress` | 메인 백엔드 API |
| `dndn-worker` | `DnDn-App/apps/worker` | `Deployment` | internal only | 비동기 작업 처리 |
| `dndn-report-api` | `DnDn-App/apps/report` | `Deployment` | `Ingress` | 보고서 API |
| `dndn-report-worker` | `DnDn-App/apps/report` | `Deployment` | internal only | 보고서 생성 worker |
| `dndn-hr` | `DnDn-HR` | `Deployment` | `Ingress` | 관리자 포털 |

`dndn-report-api`와 `dndn-report-worker`는 배포 단위는 분리하지만, 동일한 `DnDn-App/apps/report` 이미지 태그를 공유합니다.

현재 GitOps에서는 `gitops/environments/prod/apps/dndn-report` 아래에 두 Deployment가 함께 정의되어 있습니다.

## Current Prod Runtime Notes

현재 prod manifest 기준 runtime 메모는 아래와 같습니다.

| Workload | Service | Ingress | Secret | Current Notes |
| --- | --- | --- | --- | --- |
| `dndn-web` | yes | yes | no | nginx 정적 서빙, `ConfigMap` 기반 nginx 설정 |
| `dndn-api` | yes | yes | yes | AWS Secrets Manager + External Secrets Operator로 secret 주입 |
| `dndn-worker` | yes | no | no | `ConfigMap` + IRSA 기반 상시 worker |
| `dndn-report-api` | yes | yes | yes | `apps/report` 공용 이미지 사용, `/report-api` path 노출 |
| `dndn-report-worker` | no | no | yes | report 공용 이미지, worker command 고정 |
| `dndn-hr` | yes | yes | no | nginx 정적 서빙 |

현재 기준으로 `dndn-web`, `dndn-hr`, `dndn-worker`는 prod manifest에 별도 Kubernetes Secret이 없습니다.

## Ownership Model

| Area | Owner | What It Means |
| --- | --- | --- |
| 애플리케이션 코드 | `DnDn-App`, `DnDn-HR` | 코드, 이미지, 런타임 기본 설정을 소유 |
| 배포 정의 | `DnDn-Infra` | Argo CD `Application`, manifest, ingress, secret reference를 소유 |
| 환경별 설정 | `DnDn-Infra` | prod 기준 배포 규칙과 운영 절차를 소유 |

즉 워크로드 이름과 실행 단위는 함께 논의하더라도, 실제 prod 선언은 `DnDn-Infra`가 관리합니다.

## Argo CD Shape

현재 기준 Argo CD 구조는 `app-of-apps`입니다.

- root app 하나가 환경 단위를 대표
- child app이 실제 워크로드를 담당
- 환경별 값은 `gitops/environments/<env>`에 둔다

현재 실제 구현 경로:

- `gitops/bootstrap/root-app-prod.yaml`
- `gitops/environments/prod/root/*`
- `gitops/environments/prod/apps/*`

## Open Decisions

아직 남아 있는 결정은 아래입니다.

- `dndn-worker`를 장기적으로 EKS 상시 워커만으로 둘지 여부
- monitoring 스택 본체를 어느 범위까지 GitOps에 편입할지 여부
- `dev`, `staging` 환경과 도메인 전략
