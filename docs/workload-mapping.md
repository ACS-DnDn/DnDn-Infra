# Workload Mapping

이 문서는 `DnDn-App`, `DnDn-HR`를 EKS와 Argo CD 기준으로 어떤 배포 단위로 볼지 정리합니다.

현재 기준 권장 원칙은 아래와 같습니다.

- 배포 단위는 앱 실행 책임 기준으로 나눈다
- CI는 이미지 빌드와 푸시까지만 담당한다
- CD는 Argo CD가 Git 선언을 기준으로 수행한다
- `DnDn-Infra`는 배포 정의를 소유하고, 앱 레포는 실행 산출물을 소유한다

## 1. Recommended Deployment Units

현재 기준 권장 배포 단위는 아래 5개입니다.

| Workload | Source Repo | Runtime | Exposure | Notes |
| --- | --- | --- | --- | --- |
| `dndn-web` | `DnDn-App/apps/web` | `Deployment` | `Ingress` | 메인 사용자 웹 |
| `dndn-api` | `DnDn-App/apps/api` | `Deployment` | `ClusterIP` + `Ingress` | 메인 백엔드 API |
| `dndn-worker` | `DnDn-App/apps/worker` | `Deployment` | internal only | 비동기 작업 처리 |
| `dndn-report` | `DnDn-App/apps/report` | `Deployment` | internal only | 보고서 생성 서비스 |
| `dndn-hr` | `DnDn-HR` | `Deployment` | `Ingress` | 별도 관리자 프론트엔드 |

## 2. Ownership Model

- `DnDn-App`
  - 애플리케이션 코드
  - Docker image 산출물
  - 런타임 기본 설정
- `DnDn-HR`
  - HR 포털 프론트엔드 코드
  - Docker image 또는 정적 산출물
- `DnDn-Infra`
  - Helm values 또는 Kustomize overlay
  - Argo CD Application
  - 환경별 배포 규칙
  - Secret / config 주입 구조

## 3. Traffic Model

- `dndn-web`
  - 외부 사용자가 접근
  - `dndn-api`와 통신
- `dndn-hr`
  - 관리자 사용자가 접근
  - 메인 백엔드 `dndn-api`와 통신
- `dndn-worker`
  - 외부 노출 없음
  - 큐, DB, S3 같은 내부 자원 사용
- `dndn-report`
  - 외부 노출이 꼭 필요하지 않으면 내부 서비스로 유지
  - 필요 시 `dndn-api` 뒤에서 호출

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
- `apps/dndn-report`
- `apps/dndn-hr`
- `environments/dev`
- `environments/prod`

## 5. Open Decisions

아직 결정이 필요한 항목도 있습니다.

- `dndn-report`를 독립 서비스로 둘지, API 내부 기능으로 흡수할지
- `dndn-worker`를 장기적으로 EKS 상시 워커로 둘지, 일부를 Lambda로 유지할지
- `dndn-hr`를 컨테이너로 배포할지, 정적 사이트 배포로 둘지
- 환경별 도메인과 Ingress 정책
- Secret 관리 방식을 IRSA + External Secrets 기준으로 가져갈지 여부

## 6. Immediate Next Step

지금 바로 필요한 다음 작업은 아래입니다.

1. `gitops/` 디렉터리 골격 유지
2. 앱별 `Application` 초안 추가
3. 환경별 values 파일 위치와 naming 규칙 고정
