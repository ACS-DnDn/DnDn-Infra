# GitOps Flow

이 문서는 DnDn의 Argo CD 기반 GitOps 운영 흐름을 정리합니다.

현재 기준 전제는 아래와 같습니다.

- 인프라는 `DnDn-Infra`가 관리한다
- 애플리케이션 코드는 `DnDn-App`, `DnDn-HR`가 관리한다
- CI는 이미지 빌드와 푸시를 담당한다
- CD는 Argo CD가 Git 선언을 기준으로 수행한다

## 1. Repository Roles

- `DnDn-Infra`
  - Terraform
  - Argo CD Application
  - 환경별 배포 설정
  - GitOps 디렉터리
- `DnDn-App`
  - `web`, `api`, `worker`, `report` 코드
  - 이미지 산출물
- `DnDn-HR`
  - HR 프론트엔드 코드
  - 이미지 또는 정적 산출물

## 2. Recommended Promotion Flow

기본 배포 흐름은 아래와 같습니다.

1. 앱 레포에서 코드 변경
2. GitHub Actions가 이미지 빌드
3. ECR에 이미지 푸시
4. `DnDn-Infra`의 GitOps 설정에서 이미지 태그 또는 배포 값을 갱신
5. Argo CD가 변경을 감지해 클러스터에 반영

즉, 운영 기준점은 kubectl 명령이 아니라 Git 상태입니다.

## 3. Branch Strategy

현재 추천 전략은 아래와 같습니다.

- 기능 작업
  - 기능별 브랜치 사용
- GitOps 구조 작업
  - `feature/gitops-*` 브랜치 사용
- 운영 반영 기준
  - 장기적으로는 `main`을 배포 기준으로 사용

현재 `feature/gitops-foundation`은 초기 구조를 정리하는 작업 브랜치입니다.

## 4. Environment Model

현재는 아래 두 환경을 우선 기준으로 둡니다.

- `dev`
- `prod`

추천 원칙:

- `dev`에서 구조와 배포 실험
- `prod`는 승인된 값만 반영
- 환경별 차이는 `gitops/environments/<env>`에 둔다

## 5. Argo CD Model

현재 권장 구조는 `app-of-apps`입니다.

- root app 하나가 환경 단위를 대표
- child app이 실제 워크로드를 담당
- AppProject가 namespace와 source repo 범위를 제한

현재 파일 기준 매핑:

- `gitops/projects/platform.yaml`
- `gitops/bootstrap/root-app-dev.yaml`
- `gitops/apps/*.yaml`
- `gitops/environments/dev/*`

## 6. Sync Policy Guidance

현재 기준 추천 정책은 아래와 같습니다.

- `dev`
  - automated sync 허용
  - self heal 허용
  - prune 허용
- `prod`
  - 초기에는 수동 sync 또는 승인 절차 포함 검토
  - 앱 성숙도에 따라 automated 전환

## 7. What Should Not Move Yet

앱 레포 작업이 아직 완료되지 않았으므로, 아래는 지금 당장 확정하지 않습니다.

- 실제 Deployment/Service/Ingress 스펙
- 앱별 리소스 요청치
- readiness/liveness 상세 설정
- 실제 secret 키 목록
- 최종 도메인과 인증서 연결값

## 8. What We Can Fix Now

지금 단계에서 고정 가능한 것은 아래입니다.

- GitOps 디렉터리 구조
- AppProject / root app / child app 관계
- 환경 분리 방식
- 앱별 배포 단위 이름
- CI와 CD의 책임 분리

## 9. Immediate Next Step

다음 구현 단계는 아래 순서가 좋습니다.

1. `DnDn-App` 배포 입력값 정리
2. `DnDn-HR` 배포 입력값 정리
3. `dev`에서 첫 실제 앱 하나를 placeholder에서 실제 manifest로 교체
4. 이후 `prod` root app과 child app 추가
