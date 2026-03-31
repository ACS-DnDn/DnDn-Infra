# Operations Runbook

이 문서는 현재 `prod` 운영 기준의 최소 runbook을 정리합니다.

## Current Operating Assumptions

- `dndn-prod-root`
  - bootstrap root app
  - 수동 refresh / sync 기준
- child app
  - `dndn-api`, `dndn-web`, `dndn-worker`, `dndn-report`, `dndn-hr`, `dndn-monitoring`
  - automated sync + selfHeal + prune 기준
- `dndn-external-secrets`
  - Helm chart 기반 External Secrets Operator app
  - `prod/root` source에서 함께 관리
- `dndn-api`, `dndn-report`
  - AWS Secrets Manager + External Secrets Operator로 secret 동기화
- `dndn-web`, `dndn-hr`
  - nginx 기반 정적 서빙
  - prod manifest 기준 별도 Kubernetes Secret 없음
- `dndn-worker`
  - ConfigMap + IRSA 기반
  - prod manifest 기준 별도 Kubernetes Secret 없음

## Argo CD Sync Order

최초 bootstrap 또는 root app 복구가 필요할 때는 아래 진입점을 먼저 적용합니다.

```bash
kubectl apply -f gitops/bootstrap/root-app-prod.yaml -n argocd
```

현재 `prod/root` 기준 기대 순서는 아래와 같습니다.

1. `platform` AppProject
2. `dndn-external-secrets`
3. `aws-secretsmanager` ClusterSecretStore
4. child app (`dndn-api`, `dndn-report`, `dndn-web`, `dndn-worker`, `dndn-hr`, `dndn-monitoring`)

앱 내부에서는 `dndn-api`, `dndn-report`의 `ExternalSecret`이 Deployment보다 먼저 적용되도록 wave가 설정되어 있습니다.

## Standard Argo Checks

기본 확인 명령:

```bash
kubectl get applications -n argocd
kubectl get application dndn-prod-root -n argocd
kubectl get application dndn-external-secrets -n argocd
kubectl get application dndn-monitoring -n argocd
```

기대 상태:

- `dndn-prod-root`: `Synced`, `Healthy`
- child app: `Synced`, `Healthy`
- `dndn-external-secrets`: `Synced`, `Healthy`
- `dndn-monitoring`: `Synced`, `Healthy`

문제가 있을 때 순서는 아래가 안전합니다.

1. `dndn-external-secrets` 상태 확인
2. `dndn-prod-root` refresh / sync
3. `dndn-monitoring` 포함 필요한 child app만 개별 sync

## External Secrets Checks

현재 `prod`에서 secret 외부화 대상은 `dndn-api`, `dndn-report`입니다.

기본 확인 명령:

```bash
kubectl get clustersecretstore
kubectl get externalsecret -A
kubectl get secret -n dndn-api dndn-api-secret
kubectl get secret -n dndn-report dndn-report-secret
```

기대 상태:

- `ClusterSecretStore/aws-secretsmanager`: `Valid`, `Ready`
- `dndn-api-secret`, `dndn-report-secret`: `SecretSynced`, `READY=True`

AWS Secrets Manager 기준 경로:

- `/dndn/prod/api`
- `/dndn/prod/report`

## Terraform Operation Rules

현재 `terraform.yml` 운영 기준은 아래와 같습니다.

- `pull_request`
  - `terraform/**` 변경 시 `plan`
- `push` to `main`
  - `terraform/**` 변경 시 `plan -> apply`
- `workflow_dispatch`
  - `mode=plan` 또는 `mode=apply`
  - optional `target`
  - optional `reason`

수동 apply 규칙:

- `workflow_dispatch + mode=apply`는 `main` ref에서만 허용
- 다른 ref에서 수동 apply를 누르면 workflow가 명시적으로 실패

운영 권장:

- 일반 변경은 `main` 머지로 자동 apply
- 긴급 IAM / IRSA / 정책 수정은 `workflow_dispatch` 수동 apply 사용
- `target`은 hotfix에 한해 제한적으로 사용

## Image Rollout Rules

현재 prod 앱 이미지는 `.github/workflows/update-image.yml`이 반영합니다.

동작 순서:

1. 앱 레포에서 `repository_dispatch`
2. 이 레포 manifest 이미지 갱신 및 커밋
3. Bastion 경유 `kubectl set image`

운영 메모:

- 현재는 Argo CD만으로 배포가 끝나지 않는다
- manifest 커밋이 남지 않은 직접 수동 `kubectl set image`는 피하는 편이 안전하다
- 클러스터와 Git 상태가 잠깐 어긋나더라도, 최종 기준은 Git manifest다

## Runtime Verification

주요 런타임 확인 명령:

```bash
kubectl get pods -n dndn-api
kubectl get pods -n dndn-report
kubectl logs -n dndn-report deploy/dndn-report-worker --tail=100
```

현재 기준 확인 포인트:

- `dndn-api`: 모든 pod `Running`
- `dndn-report-api`, `dndn-report-worker`: `Running`
- `dndn-report-worker`
  - Bedrock `AccessDeniedException` 없어야 함
  - `HTML 생성 시작`, `HTML 저장 완료` 로그가 나오면 정상 처리로 본다

## Repo Access Note

현재 Argo CD `Application`은 `repoURL`을 직접 참조합니다.

- 예: `https://github.com/ACS-DnDn/DnDn-Infra.git`
- repo credential manifest는 현재 이 레포에 선언적으로 관리되지 않습니다

즉 현재 repo 접근 방식은 클러스터 측 별도 설정 또는 public 접근 전제를 따르고 있으며, credential 선언화는 후속 운영 과제로 남아 있습니다.

## Monitoring Note

현재 `prod` 클러스터에는 `monitoring` namespace와 `kube-prometheus-stack` 계열 구성요소가 이미 존재합니다.

- Grafana
- Prometheus
- Prometheus Operator
- kube-state-metrics
- node-exporter
- `grafana.dndn.cloud` ingress
- `dndn-api`, `dndn-report`, `dndn-worker` ServiceMonitor

현재 이 레포가 직접 관리하는 monitoring 범위는 `dndn-monitoring` child app 아래 `ServiceMonitor` 리소스뿐입니다.

다만 kube-prometheus-stack 본체의 설치 경로, chart/version, values, ownership은 이 레포 기준으로 아직 완전히 선언되지 않았고 별도 정리가 필요합니다.
