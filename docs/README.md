# Documentation Map

문서가 실제 구현 상태를 따라가도록, 이 파일을 문서 입구와 기준 문서 목록으로 유지합니다.

## Recommended Reading Order

처음 전체 구조를 잡을 때는 아래 순서가 가장 빠릅니다.

1. `architecture.md`
2. `repo-boundaries.md`
3. `workload-mapping.md`
4. `gitops-flow.md`
5. `operations-runbook.md`
6. `deploy-order.md`

## Active Docs

| Document | Covers | Update When |
| --- | --- | --- |
| `architecture.md` | 현재 구현된 전체 인프라/배포 구조 | 주요 런타임 레이어나 실제 배포 방식이 바뀔 때 |
| `repo-boundaries.md` | `DnDn-Infra`, `DnDn-App`, `DnDn-HR` 책임 경계 | 소유권, 인터페이스, 운영 경계가 바뀔 때 |
| `workload-mapping.md` | prod 워크로드 단위와 runtime 메모 | 앱 수, 배포 단위, ingress/secret 구조가 바뀔 때 |
| `gitops-flow.md` | 현재 GitOps / 이미지 반영 / Argo CD 흐름 | 이미지 갱신 절차, child app 구조, sync 방식이 바뀔 때 |
| `operations-runbook.md` | prod 운영자가 바로 따라갈 최소 운영 절차 | sync/check/apply 순서나 운영 명령이 바뀔 때 |
| `deploy-order.md` | Terraform, CFN, Lambda, 앱 배포의 실제 순서 | 배포 선행 조건과 워크플로우가 바뀔 때 |

## Current Source Of Truth

현재 기준으로 우선 참조할 문서는 아래와 같습니다.

- 전체 구조: `architecture.md`
- 책임 경계: `repo-boundaries.md`
- 워크로드 기준: `workload-mapping.md`
- GitOps 및 이미지 반영 흐름: `gitops-flow.md`
- prod 운영 절차: `operations-runbook.md`
- 배포 순서: `deploy-order.md`

현재 자주 헷갈리는 포인트와 기준 문서는 아래입니다.

- 앱 이미지는 앱 레포가 빌드하지만, prod 반영은 이 레포 워크플로우가 맡음
  - 기준 문서: `gitops-flow.md`, `deploy-order.md`
- `dndn-report`는 이미지 1개지만 `dndn-report-api`, `dndn-report-worker` 두 런타임으로 배포됨
  - 기준 문서: `workload-mapping.md`
- `dndn-api`, `dndn-report` secret은 plain Secret이 아니라 AWS Secrets Manager + External Secrets Operator 기준임
  - 기준 문서: `gitops-flow.md`, `operations-runbook.md`, `gitops/environments/prod/README.md`

## Retired Doc

- `monitoring-plan.md`
  - 계획 문서 성격이 강했고 현재 구현 정보와 분리되어 드리프트가 커져 삭제했습니다.
  - monitoring 관련 현재 상태와 한계는 `operations-runbook.md`, `gitops/README.md`, `gitops/environments/prod/README.md`에 통합합니다.

## Maintenance Rules

문서가 어긋나지 않게 하려면 아래 묶음을 같이 업데이트하는 것이 좋습니다.

- 레포 책임 변경
  - `README.md`
  - `architecture.md`
  - `repo-boundaries.md`
- 앱 배포 단위 변경
  - `workload-mapping.md`
  - `gitops-flow.md`
  - `gitops/environments/prod/README.md`
- 이미지 반영 / GitOps 절차 변경
  - `gitops-flow.md`
  - `operations-runbook.md`
  - `deploy-order.md`
  - `gitops/README.md`
- monitoring 관리 범위 변경
  - `operations-runbook.md`
  - `gitops/README.md`
  - `gitops/environments/prod/README.md`
