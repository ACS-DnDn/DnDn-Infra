# Prod Environment

이 디렉터리는 `prod` 환경용 GitOps manifest를 담습니다.

현재는 앱별 `Deployment/Service/Ingress/Secret/ConfigMap` manifest가 들어와 있습니다.
다만 Argo CD bootstrap root app과 `gitops/apps/*.yaml` 경로 정리는 아직 남아 있습니다.

현재 목적은 아래 두 가지입니다.

- `prod` 워크로드 manifest를 버전 관리
- 이후 Argo CD와 연결할 실제 소스 경로를 제공

현재 포함된 앱 경로:

- `apps/dndn-web`
- `apps/dndn-api`
- `apps/dndn-worker`
- `apps/dndn-report`
- `apps/dndn-hr`
- `ingress/`

남은 작업:

- `root/` 아래 bootstrap root app 추가
- `gitops/apps/*.yaml`를 현재 `prod` 경로 기준으로 정리
- `dndn-report`를 `report-api`, `report-worker`로 분리할지 반영
