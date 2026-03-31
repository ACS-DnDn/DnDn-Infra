# Prod Environment

이 디렉터리는 `prod` 환경용 GitOps manifest를 담습니다.

현재는 앱별 `Deployment`, `Service`, `Ingress`, `ExternalSecret`, `ConfigMap` manifest와 root source가 함께 들어 있습니다.

## Purpose

- `prod` 워크로드 manifest를 버전 관리
- Argo CD root app이 읽는 실제 소스 경로 제공

## Current Paths

- `apps/dndn-web`
- `apps/dndn-api`
- `apps/dndn-worker`
- `apps/dndn-report`
- `apps/dndn-hr`
- `apps/monitoring`
- `root/`

추가로 `root/` source 안에는 아래가 포함되어 있습니다.

- `platform` AppProject
- `dndn-external-secrets`
- `ClusterSecretStore`
- child app 선언
- Argo CD ingress

## Secrets

현재 `dndn-api`, `dndn-report`는 plain Secret manifest를 쓰지 않습니다.

External Secrets Operator가 아래 경로를 읽어 동일한 이름의 Kubernetes Secret을 동적으로 생성합니다.

- `/dndn/prod/api`
- `/dndn/prod/report`

현재 `dndn-web`, `dndn-hr`는 nginx 정적 서빙이며, `dndn-worker`는 ConfigMap + IRSA 구조라 prod manifest 기준 추가 secret 외부화 대상은 없습니다.

## Monitoring Scope

`apps/monitoring` 아래에는 현재 `dndn-api`, `dndn-report`, `dndn-worker`용 `ServiceMonitor`가 포함되어 있으며, root source에서는 `dndn-monitoring` child app으로 연결됩니다.

중요한 점은, 이 디렉터리가 직접 관리하는 monitoring 범위는 `ServiceMonitor`뿐이라는 점입니다. kube-prometheus-stack 본체 설치 경로와 values는 아직 이 레포 기준으로 완전히 선언되지 않았습니다.

## Image Rollout

현재 앱 이미지 반영은 `update-image.yml`이 수행합니다.

1. manifest `image:` 갱신 및 커밋
2. Bastion 경유 `kubectl set image`
3. Argo CD가 이후 Git 상태와 정합성 유지

## Repo Access Note

현재 Argo CD repo 접근은 public GitHub repo direct `repoURL` 구조로 확인됐고, `argocd` namespace에는 별도 repository / repo-creds secret이 없는 상태입니다.

즉 repo credential 선언화는 현재 장애 대응 항목이 아니라, private 전환 시 검토할 후속 과제입니다.

운영 절차와 검증 순서는 [docs/operations-runbook.md](../../../docs/operations-runbook.md)를 우선 기준으로 봅니다.
