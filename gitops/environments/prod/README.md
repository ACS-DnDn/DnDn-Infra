# Prod Environment

이 디렉터리는 `prod` 환경용 GitOps manifest를 담습니다.

현재는 앱별 `Deployment/Service/Ingress/ExternalSecret/ConfigMap` manifest가 들어와 있습니다.
또한 `root/kustomization.yaml`을 통해 AppProject, child app, External Secrets store, Argo CD 공용 ingress를 묶는 self-contained root source를 제공합니다.

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

추가로 `root/` source 안에는 Helm chart 기반 `dndn-external-secrets` app과 `ClusterSecretStore`가 포함되어 있어
AWS Secrets Manager 기반 secret 외부화 경로를 제공합니다.

현재 `dndn-api`, `dndn-report`는 plain Secret manifest를 제거했고, External Secrets Operator가 `/dndn/prod/api`, `/dndn/prod/report`를 읽어 동일한 이름의 Kubernetes Secret을 동적으로 생성하는 구조입니다.

남은 작업:

- monitoring 영역까지 포함한 전체 운영 기준 정리

현재 확인 기준으로 `dndn-web`, `dndn-hr`는 nginx 정적 서빙이며, `dndn-worker`는 ConfigMap + IRSA 구조라 prod manifest 기준 추가 secret 외부화 대상은 없습니다.

현재 Argo CD repo 접근은 public GitHub repo direct `repoURL` 구조로 확인됐고, `argocd` namespace에는 별도 repository / repo-creds secret이 없는 상태입니다. 즉 repo credential 선언화는 현재 장애 대응 항목이 아니라, private 전환 시 검토할 후속 과제입니다.

운영 절차와 검증 순서는 [docs/operations-runbook.md](../../../docs/operations-runbook.md)를 우선 기준으로 봅니다.
