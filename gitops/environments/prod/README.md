# Prod Environment

이 디렉터리는 `prod` 환경용 GitOps manifest를 담습니다.

상세 운영 기준은 아래 문서를 우선합니다.

- [docs/architecture.md](../../../docs/architecture.md)
- [docs/operations-runbook.md](../../../docs/operations-runbook.md)

이 README는 디렉터리 구조만 빠르게 안내합니다.

## Current Paths

- `apps/dndn-web`
- `apps/dndn-api`
- `apps/dndn-worker`
- `apps/dndn-report`
- `apps/dndn-hr`
- `apps/monitoring`
- `root/`

## Notes

- `root/`
  - Argo CD root app이 직접 읽는 self-contained source
- `apps/monitoring`
  - `ServiceMonitor`만 관리
- monitoring 본체
  - 이 디렉터리 밖에서 Helm release `kube-prometheus`로 운영
- 앱 이미지 반영
  - `update-image.yml`이 manifest를 갱신하고 Argo CD가 rollout

운영 절차와 검증 순서는 [docs/operations-runbook.md](../../../docs/operations-runbook.md)를 우선 기준으로 봅니다.
