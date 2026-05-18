# SW-Hub IaC

SW-Hub 인프라 모노레포. 역할 분리로 운영한다.

- **Terraform**: 네트워크 / EC2 / RDS 등 **인프라 프로비저닝** (AWS, `ap-northeast-2`)
- **Ansible**: 생성된 서버의 **OS·런타임 구성 관리** (Docker, zram, pgvector 등)

`terraform apply` 한 번이면 인프라가 뜨고, Ansible 인벤토리/시크릿까지 자동 생성된다.

> 설계 원칙·아키텍처 배경은 [CLAUDE.md](./CLAUDE.md) 참고.

## 구조

```text
.
├── terraform/
│   ├── environments/dev/     # dev 엔트리포인트 (provider, vars, ansible 연동)
│   └── modules/
│       ├── network/          # VPC, public/private subnet × 2, IGW, route table
│       ├── ec2/              # AMI, key pair (자동 생성), SG, 인스턴스
│       └── rds/              # subnet group, SG (EC2 SG만 허용), PostgreSQL 16
├── ansible/
│   ├── ansible.cfg           # inventory/roles 경로 등 — 이 디렉토리에서 실행
│   ├── inventories/dev/      # hosts.yml, secrets.yml은 terraform apply 시 자동 생성
│   ├── playbooks/site.yml
│   └── roles/                # common, ram_optimization, docker, postgres
└── tools/
    └── install-dependencies.sh  # AWS CLI, Terraform, Ansible 일괄 설치
```

## 사전 준비

### 1. 도구 설치

Ubuntu/WSL:

```bash
./tools/install-dependencies.sh
```

깔리는 것: AWS CLI v2, Terraform, Ansible + `community.general`, `community.postgresql` collection.

macOS: `brew install awscli terraform ansible && ansible-galaxy collection install community.general community.postgresql`

### 2. AWS 인증

```bash
aws configure
```

`terraform/environments/dev/variables.tf` 의 `aws_profile` 기본값이 `default` 라 별도 프로필명 안 줘도 동작. 다른 프로필 쓰려면 `terraform.tfvars` 에서 `aws_profile` 만 바꾸면 됨.

## 인프라 띄우기 (Terraform)

```bash
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars   # 필요 시 값 조정
terraform init
terraform apply
```

`apply` 결과:

| 산출물 | 위치 |
|---|---|
| SSH private key | `<repo-root>/sw-hub-dev.pem` (0600) |
| Ansible 인벤토리 | `ansible/inventories/dev/hosts.yml` |
| RDS 비밀번호 | `ansible/inventories/dev/group_vars/all/secrets.yml` (0600, gitignore) |
| EC2 public IP, RDS endpoint | `terraform output` |

EC2 접속:

```bash
ssh -i ../../../sw-hub-dev.pem ubuntu@$(terraform output -raw ec2_summary | jq -r '.public_ips[0]')
```

로컬에서 RDS 직접 접속 (포트포워딩):

```bash
terraform output -raw rds_tunnel_command   # 출력된 ssh -L 명령 그대로 실행
psql -h localhost -p 15432 -U swhub_admin -d swhub   # 별도 터미널
```

## 서버 구성 (Ansible)

`ansible/` 디렉토리에서 실행해야 `ansible.cfg` 가 자동 인식된다.

```bash
cd ansible
ansible -m ping all                     # 연결 확인
ansible-playbook playbooks/site.yml     # common → ram_optimization → docker → postgres
```

각 role 요약:

- **common** — 기본 패키지, timezone (Asia/Seoul)
- **ram_optimization** — zram-tools + vm.swappiness 튜닝 (작은 인스턴스용)
- **docker** — Docker CE + Compose plugin, 로그 회전 제한
- **postgres** — RDS에 pgvector 확장 설치 (psql client + `community.postgresql`)

## 정리

```bash
cd terraform/environments/dev
terraform destroy
```

EC2/RDS/네트워크/SSH 키 파일/Ansible 자동 생성 파일 전부 제거됨.