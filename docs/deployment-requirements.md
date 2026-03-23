# Deployment Requirements

이 문서는 앱 레포 구현이 마무리되기 전에, GitOps 배포를 위해 필요한 입력값을 정리합니다.

목적은 간단합니다.

- 아직 앱이 완성되지 않아도 배포 요구사항은 먼저 고정한다
- 나중에 manifest를 만들 때 다시 조사하지 않도록 한다

## 1. Common Checklist

모든 앱은 아래 항목이 확인되어야 합니다.

- 이미지 빌드 경로
- Dockerfile 위치
- 컨테이너 포트
- 필수 환경변수
- Secret 필요 여부
- Service 필요 여부
- Ingress 필요 여부
- readiness probe 필요 여부
- liveness probe 필요 여부
- HPA 필요 여부
- 사용하는 AWS 자원

## 2. Workload Requirements

| Workload | Repo Path | Runtime Type | Service | Ingress | Secret | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `dndn-web` | `DnDn-App/apps/web` | Deployment | needed | likely needed | maybe | Dockerfile / serving strategy pending |
| `dndn-api` | `DnDn-App/apps/api` | Deployment | needed | likely needed | yes | Dockerfile / runtime hardening pending |
| `dndn-worker` | `DnDn-App/apps/worker` | Deployment | maybe no | no | yes | pending app finalization |
| `dndn-report-api` | `DnDn-App/apps/report` | Deployment | needed | no or internal | yes | same image as report-worker, runtime split pending infra reflect |
| `dndn-report-worker` | `DnDn-App/apps/report` | Deployment | no | no | yes | same image as report-api, command confirmed |
| `dndn-hr` | `DnDn-HR` | Deployment | needed | needed | maybe | image publish flow ready, final runtime values pending |

## 3. Expected Inputs By App

### `dndn-web`

정리 필요:

- Dockerfile 위치
- web 앱 포트
- API base URL
- build output 방식
- 정적 빌드 후 어떤 웹서버로 서빙할지
- ingress 경로 또는 도메인

### `dndn-api`

정리 필요:

- Dockerfile 위치
- API 포트
- DB 연결 값
- Cognito 연동 값
- S3 / SQS / EventBridge 연동 값
- 내부 서비스 연결 값
- CORS 허용 도메인 방식
- 운영에서 `create_all`을 대체할 migration 전략

### `dndn-worker`

정리 필요:

- 실행 방식이 상시 worker인지 확인
- queue 이름과 URL
- DB / S3 접근값
- scale 기준

### `dndn-report-api`

정리 필요:

- 내부 서비스 포트
- API와의 호출 경로
- S3 / DB 의존성
- `apps/report` 공용 이미지의 기본 command 유지 여부

### `dndn-report-worker`

정리 필요:

- `apps/report` 공용 이미지에서 worker command 고정
- SQS queue URL
- S3 / DB 의존성
- replica / retry 정책

### `dndn-hr`

정리 필요:

- 프론트 포트 또는 정적 서빙 방식
- 메인 API 연동 URL
- 관리자 전용 도메인
- 인증 토큰 처리 방식

## 4. Infra Inputs To Prepare

인프라 레포에서 미리 준비해야 할 값은 아래입니다.

- namespace
- domain
- ingress class
- cert arn 또는 cert manager 전략
- config 주입 방식
- secret 주입 방식
- IRSA 필요 여부
- 공통 labels / naming 규칙

## 5. Decision Log

현재 기준 잠정 결정은 아래와 같습니다.

- 배포 정의는 `DnDn-Infra`가 소유
- 앱 코드는 `DnDn-App`, `DnDn-HR`가 소유
- `DnDn-App`, `DnDn-HR`의 GitHub Actions는 이미지 빌드와 푸시까지만 담당
- CD는 Argo CD 기준
- `dev` 먼저 구성
- 실제 앱 manifest 작업은 앱 PR 안정화 이후 진행
- `dndn-report-api`, `dndn-report-worker`는 동일 이미지 태그를 공유한다

## 6. Immediate Next Step

앱 레포 작업이 정리되면 아래 순서로 전환합니다.

1. 이 문서의 `pending` 항목 채우기
2. `dndn-web` placeholder 제거
3. `Deployment + Service + Ingress` 추가
4. 동일 패턴을 `api`, `hr`, `worker`, `report-api`, `report-worker`로 확장
