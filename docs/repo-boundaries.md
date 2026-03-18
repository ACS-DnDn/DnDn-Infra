# Repo Boundaries

이 문서는 `DnDn-Infra`, `DnDn-App`, `DnDn-HR`의 책임 경계를 정리합니다.

현재 세 레포는 서로 연결되어 있습니다. 하지만 앞으로 `Terraform + EKS + Argo CD` 구조로 갈수록, 각 레포가 무엇을 소유하는지 먼저 고정해두는 것이 중요합니다.

## 1. Boundary Summary

한 줄로 정리하면 아래와 같습니다.

- `DnDn-Infra`는 배포 환경과 AWS 자원을 관리한다
- `DnDn-App`은 메인 제품 코드와 실행 로직을 관리한다
- `DnDn-HR`은 조직/계정 관리 포털 코드를 관리한다

즉:

- Infra = where / how to run
- App / HR = what to run

## 2. DnDn-Infra Owns

`DnDn-Infra`가 책임져야 하는 영역입니다.

- AWS 계정 연동용 CloudFormation
- IAM / STS 연동용 인프라 자원
- EventBridge / Cognito 같은 플랫폼 공통 자원
- Terraform 기반 VPC / EKS / RDS / S3 / SQS / IAM
- 향후 Argo CD 부트스트랩
- 향후 GitOps 배포 선언
- 환경별 설정값과 배포 순서 문서

구체 예시:

- `cloudformation/dndn-ops-agent-role.yaml`
- `terraform/envs/*`
- `terraform/modules/*`
- `gitops/*` (planned)
- `docs/*`

## 3. DnDn-App Owns

`DnDn-App`이 책임져야 하는 영역입니다.

- `web`, `api`, `worker`, `report` 애플리케이션 코드
- Docker image 빌드 대상
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

## 4. DnDn-HR Owns

`DnDn-HR`이 책임져야 하는 영역입니다.

- 인사/조직/계정 관리용 프론트엔드 코드
- 사용자 / 부서 / 권한 관리 UI
- DnDn 서비스 접근 계정 관리 UI
- HR 포털 전용 라우팅 / 화면 / 클라이언트 로직
- 별도 프론트엔드 앱 빌드 산출물

현재 기준으로는 “별도 프론트엔드 앱”으로 보고, 백엔드는 메인 서비스와 연동하는 구조로 이해하는 것이 맞습니다.

## 5. Shared Interfaces

세 레포가 연결되는 인터페이스는 아래입니다.

### 1. AWS IAM / Onboarding

- Infra는 고객 계정 온보딩 스택을 제공
- App API는 CloudFormation quick-create 링크를 생성하거나 STS 연동 상태를 확인

### 2. Cognito

- Infra는 User Pool과 Client를 생성
- App과 HR은 로그인 / 토큰 / 사용자 정보 처리를 담당

### 3. SQS / S3 / RDS

- Infra는 자원을 만든다
- App과 Lambda는 그 자원을 사용한다

### 4. Organization / Account Management

- HR은 사용자, 부서, 접근 계정 관리 UI를 제공
- App은 메인 백엔드/API를 제공하고, HR은 그 백엔드와 연동한다
- Infra는 이 둘이 공통으로 사용하는 인증/배포 기반을 제공

### 5. Contracts

- App의 `contracts/`가 payload / canonical / event JSON 구조의 기준이다
- Infra의 event enricher도 가능하면 이 계약을 따라야 한다

## 6. Areas That Are Currently Blurry

지금 당장 경계가 애매한 부분도 있습니다.

### A. Event Enricher Lambda

현재 `DnDn-Infra`에는 Security Hub / AWS Health용 event enricher Lambda 코드가 있습니다.

이 코드는 성격상 중간쯤에 있습니다.

- 인프라에 가까운 이유
  - EventBridge에 직접 붙음
  - 플랫폼 수집 입구에 위치함
- 앱에 가까운 이유
  - DB 조회
  - 보고서 큐 전송
  - canonical/event 구조와 연결됨

현재는 `Infra`에 두는 것이 자연스럽지만, 반드시 `contracts` 기준과 맞춰야 합니다.

### B. Worker

`apps/worker`는 앱 레포에 있지만, 사실상 “운영 수집 엔진”입니다.

이 컴포넌트는 코드는 App이 소유하되, 배포는 Infra가 소유하는 구조가 가장 적절합니다.

즉:

- 코드 소유 = `DnDn-App`
- 배포 소유 = `DnDn-Infra`

### C. IAM Naming

현재 고객 계정 역할 이름과 온보딩 방식이 문서/코드 간 완전히 하나로 정리되어 있지 않습니다.

정리해야 할 것:

- 고객 계정 역할 이름
- ExternalId 발급/저장 방식
- Worker / event enricher가 같은 역할을 쓸지 여부

이건 빠르게 표준화해야 합니다.

### D. HR Backend Ownership

현재 확인한 `DnDn-HR`는 프론트엔드 구조가 중심입니다.

현재 이해 기준:

- HR 포털은 별도 프론트엔드 앱
- 메인 서비스 백엔드와 연동

남은 확인 포인트:

- `DnDn-App/api`를 그대로 공유하는지
- 일부 HR 전용 API를 메인 백엔드 안에 둘지
- 권한 모델을 어디서 관리할지

## 7. Recommended Ownership Model

앞으로는 아래 모델로 가는 것이 좋습니다.

### Infra owns deployment

- 어떤 AWS 자원을 만들지
- 어느 환경에 배포할지
- 어떤 값을 주입할지
- 어떤 Kubernetes manifest를 적용할지

### App owns executable artifacts

- 어떤 코드가 실행될지
- 어떤 API를 제공할지
- 어떤 payload / result schema를 따를지
- 어떤 컨테이너 이미지를 만들지

### HR owns admin portal artifacts

- 어떤 조직/계정 관리 화면을 제공할지
- 어떤 관리자용 라우팅과 인증 흐름을 쓸지
- 어떤 프론트엔드 빌드 산출물을 만들지
- 메인 백엔드와 어떻게 연동할지에 대한 프론트엔드 계약

## 8. Practical Rules

실무에서 헷갈리지 않으려면 아래 기준을 쓰면 됩니다.

### `DnDn-Infra`에 둬야 하는 것

- AWS 자원 생성 정의
- Helm / Kustomize / Argo CD Application
- 환경별 values
- Secret 주입 구조
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

### 경계에 걸릴 때 판단 기준

질문:

"이 파일이 없어도 AWS 자원 배포는 가능한가?"

- 가능하면 App 쪽일 가능성이 큼
- 불가능하면 Infra 쪽일 가능성이 큼

## 9. Recommended Next Work

지금 기준으로는 아래 순서가 좋습니다.

1. 이 문서 기준으로 역할 합의
2. `architecture.md`와 `deploy-order.md`를 함께 유지
3. Terraform 디렉터리 골격 추가
4. GitOps 디렉터리 골격 추가
5. `DnDn-App`과 `DnDn-HR` 워크로드의 배포 단위 정의

## 10. One-Line Conclusion

앞으로의 기준은 아래 한 줄이면 충분합니다.

`DnDn-App`은 메인 서비스, `DnDn-HR`은 관리자 포털, `DnDn-Infra`는 그 둘을 AWS와 Kubernetes 위에 배포하고 운영하는 레포입니다.
