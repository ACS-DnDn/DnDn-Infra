# Documentation Map

이 디렉터리는 DnDn 인프라 문서를 역할별로 나눠 관리합니다.

문서가 늘어날수록 "어디가 기준 문서인지"가 흐려지기 쉬우므로, 이 파일을 문서 입구와 관리 기준으로 사용합니다.

## 1. Recommended Reading Order

처음 합류하거나 전체 구조를 다시 잡을 때는 아래 순서로 읽는 것이 가장 빠릅니다.

1. `architecture.md`
2. `repo-boundaries.md`
3. `workload-mapping.md`
4. `deployment-requirements.md`
5. `gitops-flow.md`
6. `deploy-order.md`
7. `monitoring-plan.md`

## 2. Document Guide

| Document | Primary Question | Update When |
| --- | --- | --- |
| `architecture.md` | 전체 목표 아키텍처가 무엇인가 | 구조 레이어나 주요 런타임이 바뀔 때 |
| `repo-boundaries.md` | 어떤 레포가 무엇을 소유하는가 | 책임 경계나 공통 인터페이스가 바뀔 때 |
| `workload-mapping.md` | 어떤 앱을 어떤 배포 단위로 볼 것인가 | 워크로드 수, 런타임, 노출 방식이 바뀔 때 |
| `deployment-requirements.md` | 실제 매니페스트 작성 전에 어떤 입력값이 필요한가 | 앱 요구사항이 구체화될 때 |
| `gitops-flow.md` | GitOps 기준 배포 흐름은 무엇인가 | 승격 방식, 환경 전략, sync 정책이 바뀔 때 |
| `deploy-order.md` | 실제 배포는 어떤 순서로 진행하는가 | 인프라 선행 조건이나 운영 절차가 바뀔 때 |
| `monitoring-plan.md` | 관측성은 언제 어떤 순서로 도입하는가 | 모니터링 범위나 도입 시점이 바뀔 때 |

## 3. Current Source Of Truth

현재 기준으로 아래 문서를 우선 기준으로 봅니다.

- 책임 경계 기준: `repo-boundaries.md`
- 워크로드 기준: `workload-mapping.md`
- GitOps 승격 기준: `gitops-flow.md`
- 실제 배포 순서 기준: `deploy-order.md`
- 관측성 도입 기준: `monitoring-plan.md`

현재 최신 결정 중 특히 자주 헷갈리는 항목은 아래 문서가 기준입니다.

- `DnDn-App`, `DnDn-HR`는 image build / push까지만 담당
  - 기준 문서: `gitops-flow.md`, `repo-boundaries.md`
- `dndn-report`는 이미지 1개이지만 `dndn-report-api`, `dndn-report-worker` 두 런타임으로 배포
  - 기준 문서: `workload-mapping.md`, `deployment-requirements.md`

서로 겹치는 내용이 있더라도, 세부 결정은 위 기준 문서를 우선합니다.

## 4. Maintenance Rules

문서가 어긋나지 않게 하려면 아래 묶음을 같이 업데이트하는 것이 좋습니다.

- 레포 책임이나 소유권 변경
  - `repo-boundaries.md`
  - `architecture.md`
  - `README.md`
- 앱 배포 단위 변경
  - `workload-mapping.md`
  - `deployment-requirements.md`
  - `gitops-flow.md`
- 환경 전략이나 GitOps 구조 변경
  - `gitops-flow.md`
  - `deploy-order.md`
  - `gitops/README.md`
- 모니터링 스택이나 도입 시점 변경
  - `monitoring-plan.md`
  - 필요 시 `architecture.md`

## 5. Current Gaps

아직 문서로 완전히 닫히지 않은 항목도 있습니다.

- `dev`와 `staging` Terraform 환경 정의
- Argo CD root app 운영 절차와 sync 검증
- Lambda 패키징/배포 절차 문서
- 고객 온보딩 운영 체크리스트
- 검증 절차 문서

이 항목들은 새 문서를 추가하기보다, 먼저 기존 문서 어디에 들어갈지 기준을 정한 뒤 확장하는 것이 좋습니다.
