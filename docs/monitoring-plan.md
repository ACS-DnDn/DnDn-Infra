# Monitoring Plan

이 문서는 DnDn의 모니터링 도입 방향을 짧게 정리합니다.

현재 전제는 아래와 같습니다.

- 인프라 구축이 아직 진행 중입니다
- 현재 `prod` 클러스터에는 `monitoring` namespace와 kube-prometheus-stack 계열 구성요소가 이미 존재합니다
- 다만 설치 경로, chart/version, values, ownership이 이 레포 기준으로 문서화되어 있지 않습니다

## 1. Current Goal

지금 단계의 목표는 "모니터링을 새로 구축"하는 것이 아니라, 이미 존재하는 운영 스택의 설치 경로와 운영 책임을 정리하는 것입니다.

즉, 현재는 이미 떠 있는 Grafana / Prometheus 계열 구성을 기준으로 실상과 문서의 차이를 줄이는 쪽이 우선입니다.

## 2. Recommended Stack

| Component | Role | Start Timing |
| --- | --- | --- |
| `CloudWatch` | 기본 로그, Lambda 로그, 기본 알람 | 지금 유지 |
| `Container Insights` | EKS 클러스터/노드/파드 기본 가시성 | EKS 구조 확정 후 |
| `Amazon Managed Service for Prometheus` | 앱 및 클러스터 메트릭 수집 | 실제 워크로드 배포 후 |
| `Amazon Managed Grafana` | 대시보드 | AMP 도입 직후 |
| `X-Ray` | tracing | API 경로와 의존성 확정 후 |
| `Argo CD Notifications` | 배포 알림 | GitOps 운영 흐름 안정화 후 |

즉, 장기 방향은 `CloudWatch + AWS managed Prometheus/Grafana` 조합도 검토할 수 있지만, 현재 prod 실상은 kube-prometheus-stack 운영 상태를 먼저 문서화해야 합니다.

## 3. Why We Are Not Implementing Yet

지금 바로 새로 갈아엎지 않는 이유는 아래와 같습니다.

- 이미 운영 중인 모니터링 스택이 존재합니다
- 이 스택의 설치 경로와 변경 절차가 아직 이 레포에 정리되어 있지 않습니다
- ownership이 별도 담당자 기준으로 움직이고 있어, 바로 GitOps로 가져오기 전에 기준 합의가 필요합니다

이 상태에서 다른 스택으로 바로 갈아타면 재작업 가능성이 큽니다.

## 4. Minimum Observability For Now

현재 확인된 최소 관측은 아래입니다.

- CloudWatch 로그
- Grafana ingress (`grafana.dndn.cloud`)
- Prometheus / Prometheus Operator / node-exporter / kube-state-metrics
- GitHub Actions / Terraform 실패 확인

즉, 지금은 기본 로그와 실패 여부 추적만 확실히 유지하면 충분합니다.

## 5. Recommended Rollout Order

실제 정리 순서는 아래가 자연스럽습니다.

1. 현재 설치 경로 / chart / values / ownership 확인
2. Grafana / Prometheus / Alertmanager 운영 범위 정리
3. GitOps로 가져올 범위와 그렇지 않을 범위 분리
4. 이후 필요 시 AMP / AMG / Alerting / Tracing 재설계

## 6. Trigger To Start

아래 조건이 만족되면 추가 확장 또는 재설계를 시작합니다.

- 현재 monitoring 스택의 설치 경로와 values 확보
- ownership과 변경 절차 합의
- GitOps 편입 범위 확정

## 7. Immediate Next Step

지금 단계의 다음 액션은 운영 중인 monitoring 스택의 설치 경로와 관리 기준을 담당자와 함께 문서화하는 것입니다.
