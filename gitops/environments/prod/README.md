# Prod Environment

이 디렉터리는 `prod` 환경용 GitOps manifest를 담습니다.

현재는 앱별 `Deployment/Service/Ingress/Secret/ConfigMap` manifest가 들어와 있습니다.
또한 `root/kustomization.yaml`을 통해 AppProject, child app, Argo CD 공용 ingress를 묶는 self-contained root source를 제공합니다.

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

추가로 `root/` source 안에는 Helm chart 기반 `dndn-external-secrets` app이 포함되어 있어
secret 외부화를 위한 operator bootstrap 경로를 제공합니다.

남은 작업:

- secret / config / runtime 검증 절차 정리
- monitoring 영역까지 포함한 전체 운영 기준 정리
