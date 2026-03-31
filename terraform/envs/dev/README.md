# Dev Terraform Environment

이 디렉터리는 `dev` 환경용 Terraform 참고용 초안입니다.

현재 상태:

- prod 구성을 기준으로 env 분리만 먼저 해둔 상태
- backend 이름은 `dev` 전용으로 분리
- 아직 실제 S3 backend bucket / DynamoDB lock table은 생성하지 않음
- 아직 `terraform.tfvars` 실값도 주입하지 않음
- `route53`, `acm`, `eventbridge`, `s3_public`는 코드에 포함하되 기본값으로 비활성화
- Cognito는 prod가 재사용 중인 기존 `..._DEV` 리소스와 충돌하지 않도록 별도 참고용 이름을 명시적으로 사용
- 활성화 시점에 dev 전용 도메인, bus, 공개 bucket 전략을 다시 정하면 됨

즉 이 디렉터리는 "활성화 전 참고용으로 남겨둔 dev 초안"이며, 별도 활성화 작업 전까지 자동 apply 대상은 아닙니다.
