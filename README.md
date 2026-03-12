# DnDn-Infra

DnDn 플랫폼의 인프라 자산과 배포 기반 구성을 관리하는 저장소입니다.

이 저장소는 현재 두 레인을 함께 다룹니다.

1. **Platform Integration**
   - 고객 AWS 계정 연동용 CloudFormation 템플릿
   - 플랫폼 계정 EventBridge 수신 구성
   - Cognito 관련 초기 인프라
   - 이벤트 보강/라우팅 Lambda 코드

2. **App Runtime**
   - 추후 추가될 Terraform 기반 공통 인프라
   - 추후 추가될 Kubernetes 배포 선언서
   - `dndn-app`이 실제로 배포될 dev 런타임 기반


---

## Repository Scope

### Currently included
현재 저장소에 이미 포함된 자산입니다.

- `cloudformation/`
  - `cognito-userpool.yaml`
  - `dndn-ops-agent-role.yaml`
  - `dndn-platform-eventbus.yaml`

- `lambda/event-enricher/`
  - `event_router.py`
  - `finding_enricher.py`
  - `health_enricher.py`
  - `requirements.txt`

이 영역은 고객 계정 연동, 플랫폼 이벤트 수신, 이벤트 보강/전달을 담당합니다.

### Planned next
앞으로 점진적으로 추가할 영역입니다.

- `docs/`
- `terraform/`
- `kubernetes/`
- `scripts/`
- `.github/workflows/`

이 영역은 app runtime 인프라와 운영 문서화를 위한 골격입니다.

---

## Directory Structure

```text
DnDn-Infra/
├─ README.md
├─ .gitignore
├─ docs/
│  ├─ architecture-overview.md
│  ├─ roadmap.md
│  └─ deploy-order.md
├─ cloudformation/
│  ├─ cognito-userpool.yaml
│  ├─ dndn-ops-agent-role.yaml
│  └─ dndn-platform-eventbus.yaml
├─ lambda/
│  └─ event-enricher/
│     ├─ event_router.py
│     ├─ finding_enricher.py
│     ├─ health_enricher.py
│     └─ requirements.txt
├─ terraform/
│  ├─ envs/
│  │  └─ dev/
│  └─ modules/
├─ kubernetes/
│  ├─ addons/
│  └─ apps/
├─ scripts/
└─ .github/
   └─ workflows/