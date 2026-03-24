# Prod Environment

이 디렉터리는 `prod` 환경용 GitOps manifest를 담습니다.

현재는 앱별 `Deployment/Service/Ingress/Secret/ConfigMap` manifest가 들어와 있습니다.
또한 `root/kustomization.yaml`을 통해 AppProject, child app, 공용 ingress를 묶는 root source를 제공합니다.

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
- `root/`

남은 작업:

- Argo CD root app 실제 적용 및 sync 상태 검증
- monitoring 영역까지 포함한 전체 bootstrap 범위 최종 정리
