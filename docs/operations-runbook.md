# Operations Runbook

이 문서는 현재 `prod` 운영 기준의 최소 runbook을 정리합니다.

## Deployment Overview

현재 안전한 운영 순서는 아래입니다.

1. 플랫폼 계정 Terraform 적용
2. CloudFormation 템플릿 업로드 및 고객 계정 온보딩
3. Lambda 코드 배포
4. Argo CD root / child app 상태 확인
5. 앱 이미지 반영
6. 런타임 검증

핵심 원칙은 아래와 같습니다.

- AWS 공통 자원이 먼저 준비되어야 함
- 고객 계정은 플랫폼 EventBridge ARN을 받은 뒤 연결
- Lambda 코드는 Terraform과 별도로 배포
- 앱 이미지는 Git manifest 갱신 후 Argo CD가 반영

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

## Terraform Apply

대상 경로:

- `terraform/envs/prod`

현재 주요 output:

- `eks_cluster_name`
- `rds_endpoint`
- `rds_secret_arn`
- `cognito_user_pool_id`
- `cognito_app_client_id`
- `report_request_queue_url`
- `s3_bucket_name`
- `event_bus_arn`
- `scheduler_role_arn`
- `scheduler_group_name`
- `scheduler_trigger_lambda_arn`
- `irsa_*_role_arn`
- `acm_certificate_arn`
- `acm_hr_certificate_arn`

운영 메모:

- 현재 자동 적용 대상 환경 엔트리는 `prod`만 있음
- `terraform/envs/dev`는 코드상 scaffold만 준비된 상태
- Lambda 함수 리소스는 Terraform이 만들고, 실제 코드는 후속 워크플로우가 덮어씀

## CloudFormation Onboarding

대상:

- `.github/workflows/deploy-cfn.yml`
- `cloudformation/dndn-ops-agent-role.yaml`

초기 배포 기준:

- `EnableEventForwarding=false`
- `DnDnEventBusArn`에는 Terraform output `event_bus_arn` 사용

고객 스택 확인 포인트:

- `DnDnOpsAgentRole`
- 플랫폼 계정 `AssumeRole`
- forwarding 활성화 이후 EventBridge rule 상태

## Lambda Deployment

대상 워크플로우:

- `.github/workflows/deploy-lambda.yml`

현재 배포되는 함수:

- `dndn-prd-lmd-finding-enricher`
- `dndn-prd-lmd-health-enricher`
- `dndn-prd-lmd-scheduler-trigger`

구현 메모:

- `event-enricher`는 의존성을 포함해 패키징
- `scheduler-trigger`는 `handler.py` 단일 파일 zip

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

## RDS Credential Rule

현재 `prod` DB credential의 source of truth는 RDS managed master secret이 아니라 AWS Secrets Manager의 `dndn-prd-app-db` secret입니다.

- `finding-enricher`, `health-enricher` Lambda는 `RDS_SECRET_ARN`으로 `dndn-prd-app-db`를 사용합니다
- 현재 prod RDS는 운영상 `manage_master_user_password`를 사용하지 않습니다
- Terraform도 `master_user_secret`이 아니라 `app-db` secret 기준으로 맞춥니다

비밀번호 변경 시에는 아래를 하나의 절차로 수행합니다.

1. RDS 비밀번호 변경
2. `dndn-prd-app-db` secret 갱신
3. 관련 워크로드 재기동 또는 재배포
4. DB 연결 확인

## Terraform Operation Rules

현재 `terraform.yml` 운영 기준은 아래와 같습니다.

- `pull_request`
  - `terraform/envs/prod/**`, `terraform/modules/**`, `.github/workflows/terraform.yml` 변경 시 `plan`
- `push` to `main`
  - `terraform/envs/prod/**`, `terraform/modules/**` 변경 시 `plan -> apply`
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
3. Argo CD가 sync 상태를 맞추며 rollout

예외:

- `dndn-report`는 `dndn-report-api`, `dndn-report-worker` 두 Deployment를 함께 갱신

운영 메모:

- rollout 기준은 Argo CD sync / health 상태다
- manifest 커밋이 남지 않은 직접 수동 `kubectl set image`는 피하는 편이 안전하다
- 최종 기준은 Git manifest다

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
- `scheduler-trigger`
  - 내부 API 호출 실패가 없어야 함

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

현재 확인된 본체 정보:

- Helm release: `kube-prometheus`
- chart: `kube-prometheus-stack` `82.13.5`
- appVersion: `v0.89.0`
- namespace: `monitoring`
- Helm release secret 생성 시각: `2026-03-23T11:52:02Z`
- observed non-sensitive values
  - `alertmanager.enabled=false`
  - Grafana service: `NodePort` `30300`
  - Prometheus retention: `7d`
  - Prometheus memory: request `256Mi`, limit `512Mi`

또한 `argocd`에는 repo/repo-creds secret이 확인되지 않았고, monitoring 본체를 관리하는 별도 Application도 없습니다. `dndn-monitoring` 앱은 `ServiceMonitor` 3개만 관리합니다.

현재 운영 의도는 monitoring 본체를 앱 배포 도메인과 분리하는 것입니다.

이유:

- 앱 배포 sync 중 문제가 생겨도 Prometheus / Grafana 본체까지 같이 영향받지 않게 하기 위함
- 관측 스택을 앱 rollout 실패 도메인 밖에 두기 위함

## Monitoring Ownership And Change Rules

현재 운영 기준에서는 monitoring 본체를 `DnDn-Infra` 운영 범위로 보고, 변경 책임도 인프라 운영자에게 둡니다.

현재 관리 분리:

- Helm release `kube-prometheus`
  - Grafana / Prometheus / operator / kube-state-metrics / node-exporter 본체
- Argo CD `dndn-monitoring`
  - `ServiceMonitor` 3개만 관리

변경 절차 기준:

1. 현재 release 상태와 values를 먼저 확인
2. chart/version 변경 여부를 명시
3. Helm 변경은 운영 창구에서 수행
4. 변경 후 `monitoring` pod, Grafana ingress, Prometheus 상태 확인
5. 변경 결과를 이 레포 문서에 반영

즉 지금 단계에서는 monitoring 본체를 "레포 밖 Helm 운영", 앱 메트릭 연결만 "레포 안 GitOps 운영"으로 본다.

이 분리는 의도된 운영 정책이며, 앱 배포와 monitoring 본체를 같은 root/app-of-apps 흐름에 묶지 않는 것을 기준으로 한다.

## Private Repo Credential Strategy

private repo 전환 시 Argo CD credential은 `argocd` namespace에 직접 수기 생성하지 않고, AWS Secrets Manager + External Secrets Operator 경로로 넣는 것을 기준으로 합니다.

권장 구조:

- Secrets Manager secret
  - 예: `/dndn/prod/argocd/repo-creds`
- `argocd` namespace `ExternalSecret`
  - GitHub credential을 Argo CD용 secret으로 동기화
- Argo CD secret type
  - `repo-creds`
- URL prefix
  - `https://github.com/ACS-DnDn`

운영 원칙:

- 토큰은 Git에 두지 않음
- 가능한 한 repo 단건 secret보다 `repo-creds` prefix 방식 우선
- private cutover 전에 `Application` / `AppProject`의 `repoURL`과 credential prefix가 맞는지 검증

현재 상태:

- `argocd` namespace에 repo/repo-creds secret 없음
- public GitHub direct access 전제

## Dev Structure

현재 저장소에는 아래 scaffold가 이미 준비되어 있습니다.

```text
terraform/envs/dev

gitops/bootstrap/root-app-dev.yaml

gitops/environments/dev/apps/*
gitops/environments/dev/root/*
```

현재 상태:

- `terraform/envs/dev`
  - prod 복제 기반 참고용 env
  - backend/state 이름은 dev 전용으로 분리
  - 아직 실제 backend bucket / lock table 생성과 tfvars 값 주입은 하지 않음
  - `route53`, `acm`, `eventbridge`, `s3_public`는 코드에 포함하되 기본값으로 비활성화
- `gitops/environments/dev`
  - root app, child app, app manifest 복제본까지 준비
  - 다만 인증서 ARN, 일부 Cognito/EventBridge 값은 추후 채울 값으로 남겨둠
  - 아직 cluster bootstrap이나 child app 등록은 하지 않음

권장 운영 차이:

- `dev`
  - 구조 검증과 실험용
  - automated sync 허용
- `prod`
  - 승인된 변경만 반영

## Future Options

현재 `prod` 운영 기준으로 즉시 처리할 큰 과제는 없습니다.

필요 시 아래 항목만 후속으로 검토합니다.

- `dev` 참고용 환경 실제 활성화
  - `route53`, `acm`, `eventbridge`, `s3_public` 같은 전역 리소스 전략과 추후 채울 값 확정 포함
- private repo 전환 시 credential cutover
