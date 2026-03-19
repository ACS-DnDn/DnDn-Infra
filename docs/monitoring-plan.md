# Monitoring Plan

이 문서는 DnDn의 모니터링 도입 방향을 짧게 정리합니다.

현재 전제는 아래와 같습니다.

- 인프라 구축이 아직 진행 중입니다.
- `DnDn-App`, `DnDn-HR`도 아직 구현이 마무리되지 않았습니다.
- 따라서 지금 단계에서는 모니터링을 본격 구축하지 않고, 도입 방향과 순서만 정리합니다.

## 1. Recommended Stack

현재 기준 추천 조합은 아래와 같습니다.

- `CloudWatch`
  - 기본 로그, Lambda 로그, 기본 알람
- `Container Insights`
  - EKS 클러스터 / 노드 / 파드 기본 가시성
- `Amazon Managed Service for Prometheus`
  - EKS 및 애플리케이션 메트릭 수집
- `Amazon Managed Grafana`
  - 대시보드
- `X-Ray`
  - 추후 tracing
- `Argo CD Notifications`
  - 추후 배포 알림

즉, `Prometheus + Grafana`를 쓰되 AWS 관리형과 `CloudWatch`를 함께 사용하는 방향입니다.

## 2. Why Not Implement Now

지금 바로 구축하지 않는 이유는 아래와 같습니다.

- EKS 및 앱 구조가 아직 확정되지 않았습니다.
- 실제 워크로드 매니페스트가 아직 placeholder 상태입니다.
- 앱 메트릭, 포트, health endpoint, secret 구조가 아직 고정되지 않았습니다.

이 상태에서 AMP/AMG를 먼저 붙이면 재작업 가능성이 큽니다.

## 3. What We Keep For Now

현재 단계에서 유지할 최소 관측은 아래입니다.

- CloudWatch 로그
- Lambda 로그 확인
- GitHub Actions 실패 확인
- Terraform 실패 확인

즉, 지금은 기본 로그와 실패 가시성만 유지합니다.

## 4. Recommended Rollout Order

나중에 실제 도입은 아래 순서가 좋습니다.

1. `CloudWatch`
2. `Container Insights`
3. `AMP`
4. `AMG`
5. `Alerting`
6. `X-Ray`
7. `Argo CD Notifications`

## 5. Trigger To Start

아래 조건이 만족되면 본격 도입을 시작합니다.

- EKS 기본 구조 확정
- `DnDn-App` 주요 서비스 배포 단위 확정
- `DnDn-HR` 배포 방식 확정
- GitOps placeholder 일부 제거
- dev 환경에서 최소 1개 실제 앱 배포 완료

## 6. Next Step

지금 단계의 다음 액션은 구축이 아니라, 필요 시 이 문서를 기준으로 후속 브랜치에서 모니터링 구현 작업을 분리하는 것입니다.
