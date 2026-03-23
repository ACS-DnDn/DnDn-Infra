# Workload Mapping

이 문서는 `DnDn-App`, `DnDn-HR`를 EKS와 Argo CD 기준으로 어떤 배포 단위로 볼지 정리합니다.

현재 기준 권장 원칙은 아래와 같습니다.

- 배포 단위는 앱 실행 책임 기준으로 나눈다
- CI는 이미지 빌드와 푸시까지만 담당한다
- CD는 Argo CD가 Git 선언을 기준으로 수행한다
- `DnDn-Infra`는 배포 정의를 소유하고, 앱 레포는 실행 산출물을 소유한다

## 1. Recommended Deployment Units

현재 기준 권장 배포 단위는 아래 6개입니다.

| Workload | Source Repo | Runtime | Exposure | Primary Role |
| --- | --- | --- | --- | --- |
| `dndn-web` | `DnDn-App/apps/web` | `Deployment` | `Ingress` | 메인 사용자 웹 |
| `dndn-api` | `DnDn-App/apps/api` | `Deployment` | `ClusterIP` + `Ingress` | 메인 백엔드 API |
| `dndn-worker` | `DnDn-App/apps/worker` | `Deployment` | internal only | 비동기 작업 처리 |
| `dndn-report-api` | `DnDn-App/apps/report` | `Deployment` | internal only | 보고서 API |
| `dndn-report-worker` | `DnDn-App/apps/report` | `Deployment` | internal only | 보고서 생성 worker |
| `dndn-hr` | `DnDn-HR` | `Deployment` | `Ingress` | 관리자 포털 |

`dndn-report-api`와 `dndn-report-worker`는 배포 단위는 분리하지만, 동일한 `DnDn-App/apps/report` 이미지 태그를 공유하는 구조를 권장합니다.

## 2. Ownership Model

| Area | Owner | What It Means |
| --- | --- | --- |
| 애플리케이션 코드 | `DnDn-App`, `DnDn-HR` | 코드, 이미지, 런타임 기본 설정을 소유 |
| 배포 정의 | `DnDn-Infra` | Argo CD `Application`, overlay, values를 소유 |
| 환경별 설정 | `DnDn-Infra` | secret/config 주입 구조와 배포 규칙을 소유 |

즉, 워크로드 이름과 실행 단위는 함께 논의하더라도 실제 배포 선언은 `DnDn-Infra`가 관리합니다.

## 3. Traffic Model

워크로드별 기본 연결 관계는 아래와 같습니다.

- `dndn-web`
  - 외부 사용자가 접근
  - `dndn-api`와 통신
- `dndn-hr`
  - 관리자 사용자가 접근
  - 메인 백엔드 `dndn-api`와 통신
- `dndn-worker`
  - 외부 노출 없음
  - 큐, DB, S3 같은 내부 자원 사용
- `dndn-report-api`
  - 외부 노출이 꼭 필요하지 않으면 내부 서비스로 유지
  - 필요 시 `dndn-api` 뒤에서 호출
- `dndn-report-worker`
  - 외부 노출 없음
  - SQS를 소비하고 S3/DB 같은 내부 자원 사용

## 4. Argo CD Shape

현재 기준 추천 구조는 `app-of-apps`입니다.

- 루트 앱 하나가 환경별 앱 묶음을 관리
- 각 앱은 개별 `Application`으로 분리
- 환경별 값은 `gitops/environments/<env>`에서 관리

예상 매핑:

- `projects/platform`
- `apps/dndn-web`
- `apps/dndn-api`
- `apps/dndn-worker`
- `apps/dndn-report-api`
- `apps/dndn-report-worker`
- `apps/dndn-hr`
- `environments/dev`
- `environments/prod`

## 5. Open Decisions

아직 결정이 필요한 항목은 아래와 같습니다.

- `dndn-worker`를 장기적으로 EKS 상시 워커로 둘지, 일부를 Lambda로 유지할지
- `dndn-hr`를 컨테이너로 배포할지, 정적 사이트 배포로 둘지
- 환경별 도메인과 `Ingress` 정책
- secret 관리 방식을 `IRSA + External Secrets` 기준으로 가져갈지 여부

## 6. Immediate Next Step

지금 바로 필요한 다음 작업은 아래입니다.

1. `gitops/` 디렉터리 골격 유지
2. 앱별 `Application` 초안 유지 또는 보완
3. 환경별 values 파일 위치와 naming 규칙 고정
