# SW-Hub IaC

SW-Hub 프로젝트 인프라 모노레포. 역할 분리로 운영한다.

- **Terraform**: 네트워크/인스턴스/DB 등 **인프라 프로비저닝**
- **Ansible**: 만들어진 서버의 **OS·런타임 구성 관리**

> 작업 원칙·아키텍처 배경은 [CLAUDE.md](./CLAUDE.md) 참고.

## 구조

```text
.
├── terraform/
│   ├── environments/dev/   # dev 엔트리포인트 (AWS provider 확정)
│   └── modules/
│       ├── network/        # VPC/subnet/IGW/route table (실 리소스)
│       ├── ec2/            # 앱 노드 (placeholder)
│       └── rds/            # DB 인스턴스 (placeholder)
├── ansible/
│   ├── inventories/dev/
│   ├── playbooks/          # bootstrap.yml, site.yml
│   └── roles/              # common, docker
├── tools/
│   └── install-deps.sh     # CLI 도구 일괄 설치
└── docs/
```

## 사전 준비

Ubuntu/Debian (또는 WSL):

```bash
./tools/install-deps.sh
```

스크립트가 깔아주는 것: AWS CLI v2, Terraform, Ansible + `community.general` collection. 이미 깔린 건 건너뜀.

- macOS: `brew install awscli ansible terraform`
- Windows 네이티브: `winget install Amazon.AWSCLI Hashicorp.Terraform` (Ansible은 WSL 권장)

AWS 인증은 한 번만:

```bash
aws configure --profile sw-hub-dev
```

## Terraform

```bash
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
```

현재 `plan`에서 잡히는 건 network 모듈의 VPC/subnet/IGW/route 약 11개 자원. `ec2`/`rds`는 아직 placeholder라 변경 없음.

## Ansible

```bash
cd ansible
ansible-inventory -i inventories/dev/hosts.yml --graph
ansible-playbook -i inventories/dev/hosts.yml playbooks/bootstrap.yml --syntax-check
```

인벤토리는 placeholder. 실제 호스트 정해지면 `inventories/dev/hosts.yml` 채워야 함.

## 현재 단계

- [x] 디렉토리/모듈 골조
- [x] AWS provider 확정 (`ap-northeast-2`, named profile)
- [x] network 모듈 실 리소스 (VPC, public/private subnet × 2, IGW, route table)
- [x] ec2 모듈 실 리소스 (AMI, key pair, security group, 인스턴스)
- [x] rds 모듈 실 리소스 (subnet group, 보안그룹, PostgreSQL 16 인스턴스)
- [ ] Ansible role 실제 구현 (Docker 등)
- [ ] stage/prod 환경 분리

## CI

GitHub Actions에서 Terraform fmt/init/validate, Ansible inventory/playbook syntax-check를 돌린다.
