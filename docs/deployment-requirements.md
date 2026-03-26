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
| `dndn-web` | `DnDn-App/apps/web` | Deployment | needed | likely needed | no (current prod) | prod manifest present, nginx static serving |
| `dndn-api` | `DnDn-App/apps/api` | Deployment | needed | likely needed | yes | prod manifest present, AWS Secrets Manager + ESO 적용 |
| `dndn-worker` | `DnDn-App/apps/worker` | Deployment | maybe no | no | no (current prod) | prod manifest present, ConfigMap + IRSA 구조 |
| `dndn-report-api` | `DnDn-App/apps/report` | Deployment | needed | no or internal | yes | prod manifest present, report split reflected |
| `dndn-report-worker` | `DnDn-App/apps/report` | Deployment | no | no | yes | same image as report-api, command confirmed |
| `dndn-hr` | `DnDn-HR` | Deployment | needed | needed | no (current prod) | prod manifest present, nginx static serving |

## 3. Expected Inputs By App

### `dndn-web`

현재 기준:

- nginx 정적 서빙 Deployment
- container port `8080`
- nginx 설정은 `ConfigMap`으로 주입
- 별도 Kubernetes Secret 없음

추가로 정리할 것:

- 앱 build 시점의 API base URL 주입 방식
- ingress 경로 / 도메인 정책

### `dndn-api`

현재 기준:

- 별도 API Deployment + Service + Ingress 구조
- secret은 AWS Secrets Manager + External Secrets Operator로 주입

추가로 정리할 것:

- Cognito 연동 값
- S3 / SQS / EventBridge 연동 값
- 내부 서비스 연결 값
- CORS 허용 도메인 방식
- 운영에서 `create_all`을 대체할 migration 전략

### `dndn-worker`

현재 기준:

- 상시 worker Deployment
- queue/runtime 값은 `ConfigMap`으로 주입
- AWS 권한은 IRSA 사용
- 별도 Kubernetes Secret 없음

추가로 정리할 것:

- scale 기준
- 장기적으로 EKS worker와 별도 Lambda를 병행할지 여부

### `dndn-report-api`

현재 기준:

- `apps/report` 공용 이미지 사용
- `dndn-report-api` / `dndn-report-worker`로 runtime 분리
- secret은 AWS Secrets Manager + External Secrets Operator로 주입

추가로 정리할 것:

- 내부 서비스 포트
- API와의 호출 경로
- S3 / DB 접근 정책

### `dndn-report-worker`

현재 기준:

- `apps/report` 공용 이미지에서 worker command 고정
  - `/app/.venv/bin/python -m apps.report.src.sqs_worker`
- SQS consumer runtime
- Bedrock 호출 권한 반영 완료
- secret은 AWS Secrets Manager + External Secrets Operator로 주입

추가로 정리할 것:

- replica / retry 정책

### `dndn-hr`

현재 기준:

- nginx 정적 서빙 Deployment
- container port `8080`
- 별도 Kubernetes Secret 없음

추가로 정리할 것:

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
- `prod` root app과 child app 구조는 정리 완료
- 실제 앱 manifest는 `prod` 기준으로 먼저 운영
- `dndn-report-api`, `dndn-report-worker`는 동일 이미지 태그를 공유한다
- `dndn-api`, `dndn-report` secret은 현재 AWS Secrets Manager + External Secrets Operator 기준으로 주입한다
- `dndn-web`, `dndn-hr`, `dndn-worker`는 현재 prod manifest 기준 별도 Kubernetes Secret이 없다

## 6. Immediate Next Step

앱 레포 작업이 정리되면 아래 순서로 전환합니다.

1. 현재 `prod` manifest의 env / secret / ingress 값을 검증
2. `report-api`, `report-worker` 운영 검증 및 태그/리소스 정책 정리
3. 남은 runtime hardening과 운영 기준 정리
4. `dev`, `staging` 환경 도입 시 공통 규칙 재사용
