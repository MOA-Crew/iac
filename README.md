# SW-Hub IaC

SW-Hub 프로젝트 인프라를 관리하기 위한 모노레포입니다.

이 레포는 역할을 분리해서 운영합니다.

- **Terraform**: 네트워크, 보안 경계, 서버/인스턴스 같은 **인프라 프로비저닝**
- **Ansible**: OS 초기 설정, 패키지 설치, 런타임 준비 같은 **구성 관리**

지금 단계는 **깊은 구현 전의 초기 골조 세팅**입니다.
즉, 바로 다음 작업에서 클라우드/서버 실구성을 붙일 수 있도록 뼈대를 먼저 만든 상태입니다.

## 저장소 구조

```text
.
├── ansible/
│   ├── inventories/
│   │   └── dev/
│   ├── playbooks/
│   └── roles/
├── docs/
├── CLAUDE.md
└── terraform/
    ├── environments/
    │   └── dev/
    └── modules/
        ├── compute/
        └── network/
```

## 왜 이렇게 나눴나

### Terraform
Terraform은 아래처럼 **선언적으로 깔아야 하는 자원**을 담당합니다.

- VPC / Subnet / Routing
- Security Group / Firewall 경계
- VM / Instance / Node 그룹
- 이후 필요 시 Load Balancer, NAT, DB 등

### Ansible
Ansible은 **이미 만들어진 서버를 어떻게 쓸 수 있는 상태로 만들지**를 담당합니다.

- 공통 패키지 설치
- 타임존 / 기본 시스템 설정
- Docker 등 런타임 준비
- 앱 배포 전 서버 베이스라인 정리

이렇게 나누면 역할이 선명해서, 나중에 인프라 변경과 서버 설정 변경이 서로 덜 꼬입니다.

## 현재 포함된 것

### Terraform
- `terraform/environments/dev`: dev 환경 엔트리포인트
- `terraform/modules/network`: 네트워크 모듈 뼈대
- `terraform/modules/compute`: 컴퓨트 모듈 뼈대

### Ansible
- `ansible/inventories/dev`: dev 인벤토리 예시
- `ansible/playbooks/bootstrap.yml`: 전체 서버 기본 부트스트랩
- `ansible/playbooks/site.yml`: 앱 서버 대상 기본 런타임 적용
- `ansible/roles/common`: 공통 기본 설정
- `ansible/roles/docker`: Docker 관련 placeholder 역할

## Quick start

## 1) 미리 설치할 것

로컬에서 아래 도구들이 필요합니다.

- `git`
- `terraform` (권장: 1.6 이상)
- `python3`, `pip`
- `ansible-core`
- Ansible Collection: `community.general`

예시:

### Ubuntu / Debian 계열

```bash
sudo apt update
sudo apt install -y git unzip python3 python3-pip
```

Terraform은 공식 설치 방식을 권장합니다.

Ansible은 예를 들어 이렇게 준비할 수 있습니다.

```bash
python3 -m pip install --user ansible-core
ansible-galaxy collection install community.general
```

### macOS (Homebrew)

```bash
brew install git terraform python ansible
ansible-galaxy collection install community.general
```

## 2) Terraform 시작

```bash
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform validate
terraform plan
```

## 3) Ansible 시작

```bash
cd ansible
ansible-inventory -i inventories/dev/hosts.yml --graph
ansible-playbook -i inventories/dev/hosts.yml playbooks/bootstrap.yml --syntax-check
ansible-playbook -i inventories/dev/hosts.yml playbooks/site.yml --syntax-check
```

## 현재 기준 아키텍처 방향

현재는 **사진 기반 초기 해석 + 최소 골조 반영** 수준으로 잡았습니다.

핵심 방향은 이렇습니다.

- 외부에서 바로 모든 서버에 붙지 않도록 **진입 계층과 내부 앱 계층을 분리**
- 관리/접속용 노드 또는 공개 진입점을 먼저 두고,
- 실제 애플리케이션 서버는 **내부 네트워크(private 성격)** 로 두는 구조
- dev 기준으로는 `bastion` 1대 + `app` 노드 2대 형태의 placeholder를 먼저 둠
- 이후 필요하면 DB, 캐시, 모니터링, 프록시 계층을 별도 역할로 확장

즉, 지금 레포는 “작동하는 완성품”이라기보다,
**SW-Hub 인프라를 안전하게 키워나갈 수 있는 첫 번째 기준선**입니다.

## 검증

GitHub Actions에서 아래를 확인하도록 해두었습니다.

- Terraform fmt / init / validate
- Ansible inventory 확인
- Ansible playbook syntax-check

## 다음 추천 작업

1. 실제 클라우드/호스팅 타겟 확정
2. Terraform provider 추가
3. dev inventory의 실제 IP/호스트명 반영
4. Docker / reverse proxy / app deploy role 구체화
5. stage / prod 환경 분리
