# Repo Boundaries

이 문서는 `DnDn-Infra`, `DnDn-App`, `DnDn-HR`의 책임 경계를 정리합니다.

현재 세 레포는 서로 연결되어 있습니다. 하지만 앞으로 `Terraform + EKS + Argo CD` 구조로 갈수록, 각 레포가 무엇을 소유하는지 먼저 고정해두는 것이 중요합니다.

## 1. Boundary Summary

현재 기준 한 줄 요약은 아래와 같습니다.

- `DnDn-Infra`는 where / how to run 을 관리한다
- `DnDn-App`, `DnDn-HR`는 what to run 을 관리한다

좀 더 풀면 아래와 같습니다.

| Repo | Owns | Does Not Own |
| --- | --- | --- |
| `DnDn-Infra` | AWS 자원, 배포 환경, GitOps 선언, 환경별 값 | 제품 기능 로직, 화면 로직 |
| `DnDn-App` | 메인 제품 코드, API, worker, contracts, 이미지 산출물 | AWS 자원 생성, Argo CD 선언, EKS 직접 배포 |
| `DnDn-HR` | 관리자 포털 UI, HR 전용 프론트엔드 산출물 | 플랫폼 공통 인프라, 메인 API 배포, EKS 직접 배포 |

## 2. Repository Ownership

### `DnDn-Infra`

`DnDn-Infra`가 책임져야 하는 영역입니다.

- AWS 계정 연동용 CloudFormation
- IAM / STS / EventBridge / Cognito 같은 플랫폼 공통 자원
- Terraform 기반 VPC / EKS / RDS / S3 / SQS / IAM
- Argo CD 부트스트랩과 GitOps 배포 선언
- 환경별 설정값과 배포 순서 문서

구체 예시:

- `cloudformation/dndn-ops-agent-role.yaml`
- `terraform/envs/*`
- `terraform/modules/*`
- `gitops/*`
- `docs/*`

### `DnDn-App`

`DnDn-App`이 책임져야 하는 영역입니다.

- `web`, `api`, `worker`, `report` 애플리케이션 코드
- Docker image 빌드 대상
- GitHub Actions 기반 image push
- 비즈니스 로직
- 보고서 생성 로직
- worker 실행 로직
- contracts / schema
- 앱 내부 테스트와 실행 방법

구체 예시:

- `apps/web`
- `apps/api`
- `apps/worker`
- `apps/report`
- `contracts`

### `DnDn-HR`

`DnDn-HR`이 책임져야 하는 영역입니다.

- 인사/조직/계정 관리용 프론트엔드 코드
- 사용자 / 부서 / 권한 관리 UI
- DnDn 서비스 접근 계정 관리 UI
- HR 포털 전용 라우팅 / 화면 / 클라이언트 로직
- 별도 프론트엔드 앱 빌드 산출물

현재 기준으로는 별도 프론트엔드 앱으로 보고, 백엔드는 메인 서비스와 연동하는 구조로 이해하는 것이 맞습니다.

## 3. Shared Interfaces

세 레포가 연결되는 주요 인터페이스는 아래와 같습니다.

| Interface | Infra | App / HR |
| --- | --- | --- |
| AWS IAM / Onboarding | 고객 계정 온보딩 스택 제공 | 연동 링크 생성, 상태 확인 |
| Cognito | User Pool / Client 생성 | 로그인, 토큰, 사용자 정보 처리 |
| SQS / S3 / RDS | 자원 생성 | 런타임에서 사용 |
| Organization / Account Management | 인증/배포 기반 제공 | HR UI와 메인 API 연동 |
| Contracts | 인프라 연동 코드가 계약을 따라야 함 | `contracts/`가 payload 기준이 됨 |

특히 `contracts`는 `DnDn-App`이 기준을 잡고, `DnDn-Infra`의 event enricher도 가능한 한 이를 따라야 합니다.

## 4. Blurry Areas And Current Decisions

지금 당장 경계가 애매한 부분은 아래처럼 정리합니다.

| Area | Why It Is Blurry | Current Decision |
| --- | --- | --- |
| Event enricher Lambda | EventBridge에 붙지만 DB와 queue도 사용 | 현재는 `Infra`에 두되 `contracts` 기준 준수 |
| Worker | 앱 코드이지만 운영 수집 엔진 성격도 강함 | 코드 소유는 `App`, 배포 소유는 `Infra` |
| IAM naming | 역할 이름과 ExternalId 규칙이 완전히 통일되지 않음 | 빠르게 표준화 필요 |
| HR backend ownership | HR이 별도 프론트엔드인지, 일부 API도 갖는지 아직 미확정 | 현재는 메인 백엔드 연동형으로 가정 |

남은 확인 포인트:

- 고객 계정 역할 이름
- ExternalId 발급/저장 방식
- Worker / event enricher가 같은 역할을 쓸지 여부
- HR 전용 API를 메인 백엔드 안에 둘지 여부

## 5. Practical Rules

실무에서 헷갈리지 않으려면 아래 기준을 우선 적용합니다.

### `DnDn-Infra`에 둬야 하는 것

- AWS 자원 생성 정의
- Helm / Kustomize / Argo CD `Application`
- 환경별 values
- secret 주입 구조
- 네트워크 / IAM / cluster 구성

### `DnDn-App`에 둬야 하는 것

- Python / TypeScript / React / FastAPI 코드
- Dockerfile
- 앱 실행 설정의 기본값
- API payload / response schema
- worker 처리 로직

### `DnDn-HR`에 둬야 하는 것

- HR 포털 React 코드
- 조직/사용자/부서 관리 UI
- 관리자용 로그인 이후 화면 흐름
- HR 포털 전용 프론트엔드 빌드 설정
- 메인 API 호출 클라이언트 로직

경계에 걸릴 때 판단 기준은 아래 질문 하나면 충분합니다.

"이 파일이 없어도 AWS 자원 배포는 가능한가?"

- 가능하면 App / HR 쪽일 가능성이 큽니다
- 불가능하면 Infra 쪽일 가능성이 큽니다

## 6. Recommended Next Work

지금 기준으로는 아래 순서가 좋습니다.

1. 이 문서 기준으로 역할 합의
2. `architecture.md`와 `deploy-order.md`를 함께 유지
3. `operations-runbook.md`를 기준으로 GitOps 변경 절차 유지
4. image tag / 환경 확장 / repo credential 정책 정리
5. `DnDn-App`, `DnDn-HR` 워크로드의 운영 검증 기준 정리

## 7. One-Line Conclusion

`DnDn-App`은 메인 서비스, `DnDn-HR`은 관리자 포털, `DnDn-Infra`는 그 둘을 AWS와 Kubernetes 위에 배포하고 운영하는 레포입니다.
