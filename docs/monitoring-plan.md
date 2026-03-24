# Monitoring Plan

이 문서는 DnDn의 모니터링 도입 방향을 짧게 정리합니다.

현재 전제는 아래와 같습니다.

- 인프라 구축이 아직 진행 중입니다
- `DnDn-App`, `DnDn-HR`도 아직 구현이 마무리되지 않았습니다
- 따라서 지금은 풀 스택 구축보다 도입 시점과 우선순위를 먼저 고정하는 단계입니다

## 1. Current Goal

지금 단계의 목표는 "모니터링 시스템 구축"이 아니라 "나중에 재작업이 적은 도입 순서 정리"입니다.

즉, 현재는 최소 로그와 실패 가시성만 유지하고, 앱 구조가 고정된 뒤 메트릭과 알림을 확장합니다.

## 2. Recommended Stack

| Component | Role | Start Timing |
| --- | --- | --- |
| `CloudWatch` | 기본 로그, Lambda 로그, 기본 알람 | 지금 유지 |
| `Container Insights` | EKS 클러스터/노드/파드 기본 가시성 | EKS 구조 확정 후 |
| `Amazon Managed Service for Prometheus` | 앱 및 클러스터 메트릭 수집 | 실제 워크로드 배포 후 |
| `Amazon Managed Grafana` | 대시보드 | AMP 도입 직후 |
| `X-Ray` | tracing | API 경로와 의존성 확정 후 |
| `Argo CD Notifications` | 배포 알림 | GitOps 운영 흐름 안정화 후 |

즉, 방향은 `CloudWatch + AWS managed Prometheus/Grafana` 조합입니다.

## 3. Why We Are Not Implementing Yet

지금 바로 구축하지 않는 이유는 아래와 같습니다.

- EKS와 앱 구조가 아직 확정되지 않았습니다
- `prod` root app과 child app wiring은 정리됐지만, 앱별 metrics / logs / alert 기준이 아직 운영 기준으로 고정되지 않았습니다
- 앱 메트릭, 포트, health endpoint, secret 구조가 아직 고정되지 않았습니다

이 상태에서 AMP/AMG를 먼저 붙이면 재작업 가능성이 큽니다.

## 4. Minimum Observability For Now

현재 단계에서 유지할 최소 관측은 아래입니다.

- CloudWatch 로그
- Lambda 로그 확인
- GitHub Actions 실패 확인
- Terraform 실패 확인

즉, 지금은 기본 로그와 실패 여부 추적만 확실히 유지하면 충분합니다.

## 5. Recommended Rollout Order

실제 도입은 아래 순서가 자연스럽습니다.

1. `CloudWatch`
2. `Container Insights`
3. `AMP`
4. `AMG`
5. `Alerting`
6. `X-Ray`
7. `Argo CD Notifications`

## 6. Trigger To Start

아래 조건이 만족되면 본격 도입을 시작합니다.

- EKS 기본 구조 확정
- `DnDn-App` 주요 서비스 배포 단위 확정
- `DnDn-HR` 배포 방식 확정
- Argo CD root app과 child app wiring 완료
- `dev` 환경에서 최소 1개 실제 앱 배포 완료

## 7. Immediate Next Step

지금 단계의 다음 액션은 구축이 아니라, 후속 브랜치에서 모니터링 구현 작업을 분리할 수 있도록 이 문서를 기준선으로 유지하는 것입니다.
