# GitOps

이 디렉터리는 Argo CD 기반 GitOps 선언을 관리합니다.

현재 기준 운영 원칙은 아래와 같습니다.

- Git manifest가 배포 기준 상태가 된다
- 현재 prod 이미지 반영은 Git manifest 갱신과 Bastion 즉시 롤아웃이 함께 간다
- Argo CD는 이후 Git 상태 기준으로 정합성을 유지한다
- 앱별 배포 정의와 환경별 설정을 분리한다

## Layout

```text
gitops/
├─ bootstrap/
├─ projects/
├─ apps/
└─ environments/
   └─ prod/
```

현재 실제 구현 환경은 `prod`만 있습니다.

## Directory Purpose

- `bootstrap/`
  - Argo CD 초기 설치 이후 적용할 root app 선언
- `projects/`
  - Argo CD AppProject 정의
- `apps/`
  - child app 정의의 공유 위치
- `environments/`
  - 환경별 manifest와 root source

## Current Files

- `projects/platform.yaml`
  - 공통 AppProject
- `apps/*.yaml`
  - child app 정의의 공유 복사본
- `bootstrap/root-app-prod.yaml`
  - `prod` root app 진입점
- `environments/prod/root/*`
  - Argo CD가 직접 읽는 self-contained root source
- `environments/prod/apps/*`
  - `prod` 워크로드 manifest
- `environments/prod/apps/monitoring/*`
  - `dndn-api`, `dndn-report`, `dndn-worker`용 `ServiceMonitor`
- `environments/prod/apps/dndn-api/externalsecret.yaml`
  - `dndn-api-secret`을 AWS Secrets Manager에서 동기화
- `environments/prod/apps/dndn-report/externalsecret.yaml`
  - `dndn-report-secret`을 AWS Secrets Manager에서 동기화

현재 워크로드 기준 참고:

- `dndn-web`
- `dndn-api`
- `dndn-worker`
- `dndn-report-api`
- `dndn-report-worker`
- `dndn-hr`
- `dndn-monitoring`

`dndn-report-api`와 `dndn-report-worker`는 동일한 `DnDn-App/apps/report` 이미지 태그를 공유합니다.

## Current Flow

1. Terraform으로 EKS와 공통 런타임을 준비
2. `bootstrap/root-app-prod.yaml`로 root app 적용
3. Argo CD가 `environments/prod/root`를 기준으로 child app 구성
4. `update-image.yml`이 manifest 이미지를 갱신하고 커밋
5. 같은 워크플로우가 Bastion에서 즉시 롤아웃
6. Argo CD가 이후 Git 상태를 유지

## Notes

현재 prod 운영에서 Argo CD가 직접 읽는 source의 기준은 `gitops/environments/prod/root/*` 입니다.

`gitops/apps/*.yaml`는 child app 정의를 공유하는 위치이지만, 실제 bootstrap 기준점은 root source 쪽입니다.

또한 앱 레포는 이미지 빌드와 푸시를 담당하고, 실제 prod 반영은 이 레포의 `update-image.yml`과 Argo CD가 함께 맡는 구조입니다.

현재 `dndn-api`, `dndn-report` secret은 Git의 plain Kubernetes Secret manifest가 아니라 AWS Secrets Manager와 External Secrets Operator를 통해 동기화됩니다.

현재 `dndn-web`, `dndn-hr`는 nginx 정적 서빙 기반이고, `dndn-worker`는 ConfigMap + IRSA 기반이므로 prod manifest 기준 추가 Kubernetes Secret은 없습니다.

현재 `dndn-monitoring` app이 관리하는 것은 `ServiceMonitor`뿐이며, kube-prometheus-stack 본체 설치 정보는 이 디렉터리에 완전히 선언되어 있지 않습니다.

운영 절차와 sync 순서는 [docs/operations-runbook.md](../docs/operations-runbook.md)를 기준으로 봅니다.
