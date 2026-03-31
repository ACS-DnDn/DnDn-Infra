# Dev Environment

이 디렉터리는 `dev` 환경용 GitOps 참고용 소스입니다.

현재 상태:

- `root/`
  - prod app-of-apps 구조를 따라간 dev 전용 Application/AppProject 선언 포함
- `apps/`
  - `web`, `api`, `worker`, `report`, `hr`, `monitoring` manifest까지 포함
  - 다만 인증서 ARN, 일부 Cognito/EventBridge 값은 추후 채울 값으로 남겨둠
- `gitops/bootstrap/root-app-dev.yaml`
  - 필요 시 적용할 진입점으로만 준비됨
