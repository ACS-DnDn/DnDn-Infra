# GitOps Flow

이 문서는 DnDn의 Argo CD 기반 GitOps 운영 흐름을 정리합니다.

## 1. Core Flow

현재 기준 기본 흐름은 아래 한 줄로 요약할 수 있습니다.

`앱 레포 코드 변경 -> CI 이미지 빌드/푸시 -> Infra 레포 GitOps 값 갱신 -> Argo CD 동기화`

핵심 원칙은 두 가지입니다.

- CI는 실행 산출물을 만든다
- CD는 Git 선언 상태를 클러스터에 반영한다

현재 기준으로는 아래처럼 책임을 더 명확히 나눕니다.

- `DnDn-App`, `DnDn-HR`의 GitHub Actions는 Docker image 빌드와 ECR 푸시까지만 담당한다
- 실제 Helm/Kustomize values, Argo CD `Application`, EKS 반영은 `DnDn-Infra`가 담당한다

즉, 운영 기준점은 `kubectl`이 아니라 Git 상태입니다.

## 2. Ownership In The Flow

| Area | Owner | Responsibility |
| --- | --- | --- |
| 애플리케이션 코드 | `DnDn-App`, `DnDn-HR` | 코드 변경, 이미지 산출물 |
| 배포 환경 | `DnDn-Infra` | Terraform, GitOps 구조, 환경별 설정 |
| 이미지 빌드/푸시 | GitHub Actions | 이미지 생성, 레지스트리 푸시 |
| 선언 반영 | Argo CD | Git 변경 감지, EKS 반영 |

현재 이 문서의 전제는 아래와 같습니다.

- 인프라는 `DnDn-Infra`가 관리한다
- 애플리케이션 코드는 `DnDn-App`, `DnDn-HR`가 관리한다
- CI는 이미지 빌드와 푸시를 담당한다
- CD는 Argo CD가 Git 선언을 기준으로 수행한다
- 앱 레포 workflow는 `aws eks update-kubeconfig` 또는 `helm upgrade --install`을 직접 수행하지 않는다

## 3. Promotion Model

현재 권장 승격 흐름은 아래와 같습니다.

1. 앱 레포에서 기능 브랜치 작업
2. 앱 CI가 이미지 빌드 및 푸시
3. `DnDn-Infra`에서 GitOps 이미지 태그 또는 환경 값을 갱신
4. `dev`에서 배포 확인
5. 승인된 변경만 `prod`에 반영

예시:

- `DnDn-App/apps/report`는 하나의 이미지 태그를 발행한다
- `DnDn-Infra`는 그 태그를 `dndn-report-api`, `dndn-report-worker` 두 런타임에 함께 반영한다

장기 기준 운영 브랜치는 `main`입니다.

GitOps 구조 자체를 바꾸는 작업은 `feature/gitops-*` 브랜치에서 분리하는 것이 안전합니다.

## 4. Environment Strategy

현재 문서 기준 목표 환경은 아래 두 가지지만, 실제 파일 기준 GitOps manifest는 현재 `prod`에 먼저 들어와 있습니다.

| Environment | Role | Guidance |
| --- | --- | --- |
| `dev` | 구조 검증과 배포 실험 | automated sync, self heal, prune 허용 |
| `prod` | 승인된 선언 반영 | 초기에는 수동 sync 또는 승인 절차 권장 |

공통 원칙:

- 환경별 차이는 `gitops/environments/<env>`에 둔다
- root app은 환경 단위를 대표한다
- child app은 실제 워크로드 단위를 담당한다

## 5. Argo CD Shape

현재 권장 구조는 `app-of-apps`입니다.

- root app 하나가 환경 단위를 대표
- child app이 실제 워크로드를 담당
- AppProject가 namespace와 source repo 범위를 제한

현재 파일 기준 매핑은 아래와 같습니다.

- `gitops/projects/platform.yaml`
- `gitops/bootstrap/` (`.gitkeep`만 존재 — root app 미구현)
- `gitops/apps/*.yaml`
- `gitops/environments/prod/apps/*`
- `gitops/environments/prod/ingress/*`

주의:

- 현재 `gitops/apps/*.yaml`는 여전히 `dev` 경로를 가리키고 있습니다
- 실제 manifest는 `gitops/environments/prod/*`에 존재하므로, Argo CD wiring 정리가 필요합니다

## 6. Fixed Now vs Later

지금 단계에서 먼저 고정할 항목:

- GitOps 디렉터리 구조
- AppProject / root app / child app 관계
- 환경 분리 방식
- 앱별 배포 단위 이름
- CI와 CD의 책임 분리

아직 고정하지 않을 항목:

- 실제 `Deployment/Service/Ingress` 스펙
- 앱별 리소스 요청치
- readiness/liveness 상세 설정
- 실제 secret 키 목록
- 최종 도메인과 인증서 연결값

## 7. Immediate Next Step

다음 구현 단계는 아래 순서가 가장 자연스럽습니다.

1. `DnDn-App` 배포 입력값 정리
2. `DnDn-HR` 배포 입력값 정리
3. `gitops/apps/*.yaml`를 실제 `prod` 경로 기준으로 정리
4. `prod` root app과 bootstrap 선언 추가
5. 이후 `report-api`, `report-worker` 분리 여부 반영
