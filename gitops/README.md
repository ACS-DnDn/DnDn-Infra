# GitOps

이 디렉터리는 Argo CD 기반 GitOps 선언을 위한 골격입니다.

현재 기준 운영 원칙은 아래와 같습니다.

- Git이 배포의 기준 상태가 된다
- GitHub Actions는 이미지 빌드와 푸시까지만 담당한다
- Argo CD가 Git 변경을 감지해 EKS에 반영한다
- 앱별 배포 정의와 환경별 설정을 분리한다

## Layout

```text
gitops/
├─ bootstrap/
├─ projects/
├─ apps/
└─ environments/
   ├─ dev/
   └─ prod/
```

## Directory Purpose

- `bootstrap/`
  - Argo CD 초기 설치 이후 적용할 루트 앱 또는 bootstrap 선언
- `projects/`
  - Argo CD AppProject 정의
- `apps/`
  - 앱별 Application 정의
- `environments/`
  - 환경별 values, 공통 설정, 환경 차이점

## Current Files

- `projects/platform.yaml`
  - 공통 AppProject
- `bootstrap/root-app-dev.yaml`
  - dev 환경 root application
- `apps/*.yaml`
  - 앱별 child application
- `environments/dev/apps/*`
  - 앱별 placeholder manifest
- `environments/dev/root/kustomization.yaml`
  - dev root app entrypoint

## Recommended Flow

1. Terraform으로 EKS와 Argo CD 런타임을 준비
2. `bootstrap/`으로 root application 적용
3. `apps/`와 `environments/`를 기준으로 앱 배포 관리
4. 앱 레포 이미지 태그 변경을 Git에 반영
5. Argo CD가 자동 동기화

## Notes

현재 `dev` 환경에는 placeholder `ConfigMap`만 들어 있습니다.
실제 배포 시에는 각 앱 경로를 Helm chart 또는 실제 manifest로 교체하면 됩니다.
