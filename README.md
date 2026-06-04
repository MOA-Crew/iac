# SW-Hub IaC

SW-Hub 인프라 모노레포. 역할 분리로 운영한다.

- **Terraform**: 네트워크 / EC2 / RDS / S3 / Cloudflare DNS·Tunnel 등 **인프라 프로비저닝**
- **Ansible**: 생성된 서버의 **OS·런타임 구성 관리** (Docker, zram, Redis, cloudflared, pgvector 등)

현재 dev 환경은 EC2 앱 서버 + RDS PostgreSQL + EC2 로컬 Redis + Cloudflare Tunnel 진입 구조다. EC2의 앱 포트는 직접 공개하지 않고, 공개 HTTPS 트래픽은 Cloudflare Tunnel을 통해 들어온다.

> 설계 원칙·아키텍처 배경은 [CLAUDE.md](./CLAUDE.md) 참고.

## 구조

```text
.
├── terraform/
│   ├── environments/dev/     # dev 엔트리포인트 (AWS/Cloudflare provider, vars, ansible 연동)
│   └── modules/
│       ├── network/          # VPC, public/private subnet × 2, IGW, route table
│       ├── ec2/              # AMI, key pair (자동 생성), SG, 인스턴스
│       ├── rds/              # subnet group, SG (EC2 SG만 허용), PostgreSQL 16
│       └── s3/               # dev용 S3 bucket
├── ansible/
│   ├── ansible.cfg           # inventory/roles 경로 등 — 이 디렉토리에서 실행
│   ├── inventories/dev/      # hosts.yml, secrets.yml은 terraform apply 시 자동 생성
│   ├── playbooks/site.yml
│   └── roles/                # common, ram_optimization, docker, redis, cloudflared, postgres
└── tools/
    └── install-dependencies.sh  # AWS CLI, Terraform, Ansible 일괄 설치
```

## 현재 dev 구성 요약

- **AWS**: VPC / EC2 app node / RDS PostgreSQL / S3
- **Redis**: 비용 절감을 위해 ElastiCache 대신 EC2 내부 Docker Compose Redis 사용
  - 기본 바인딩: `127.0.0.1:6379`
  - 외부 공개 금지, 필요 시 ElastiCache 이전 고려
- **Cloudflare**: DNS record + Zero Trust Tunnel을 Terraform으로 관리
  - API token은 `CLOUDFLARE_API_TOKEN` 환경변수로 주입
  - 계정/존/호스트명/origin은 `TF_VAR_*` 환경변수로 교체 가능
- **cloudflared**: Ansible role이 EC2에서 Docker Compose 서비스로 실행
  - tunnel token과 public hostname은 환경변수/extra-var로 주입

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

### 3. Cloudflare 변수

Cloudflare token과 도메인 관련 값은 코드에 하드코딩하지 않고 환경변수로 주입한다.

```bash
export CLOUDFLARE_API_TOKEN=...
export TF_VAR_cloudflare_account_id=...
export TF_VAR_cloudflare_zone_name=...
export TF_VAR_cloudflare_hostname=...
export TF_VAR_cloudflare_tunnel_name=...
export TF_VAR_cloudflare_origin_service=...
```

기존 Cloudflare 리소스를 Terraform state로 가져올 때는 `terraform/environments/dev/CLOUDFLARE.md` 참고.

## 인프라 띄우기 (Terraform)

```bash
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars   # 필요 시 값 조정. 민감값/실제 도메인은 커밋 금지
terraform init
terraform apply
```

`apply` 결과:

| 산출물 | 위치 |
|---|---|
| SSH private key | `<repo-root>/sw-hub-dev.pem` (0600) |
| Ansible 인벤토리 | `ansible/inventories/dev/hosts.yml` |
| RDS 비밀번호 | `ansible/inventories/dev/group_vars/all/secrets.yml` (0600, gitignore) |
| Cloudflare tunnel token | `terraform output -raw cloudflare_tunnel_token` (민감값) |
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
ansible -m ping all
export MOA_PUBLIC_HOSTNAME=...
export CLOUDFLARED_TUNNEL_TOKEN=...
ansible-playbook playbooks/site.yml
```

각 role 요약:

- **common** — 기본 패키지, timezone (Asia/Seoul)
- **ram_optimization** — zram-tools + vm.swappiness 튜닝 (작은 인스턴스용)
- **docker** — Docker CE + Compose plugin, 로그 회전 제한
- **redis** — EC2 내부 Redis Compose 서비스 (`127.0.0.1:6379`)
- **cloudflared** — Cloudflare Tunnel connector Compose 서비스
- **postgres** — RDS에 pgvector 확장 설치 (psql client + `community.postgresql`)

필요한 role만 실행할 수도 있다.

```bash
ansible-playbook playbooks/site.yml --tags redis
ansible-playbook playbooks/site.yml --tags cloudflared
```

## 정리

```bash
cd terraform/environments/dev
terraform destroy
```

EC2/RDS/S3/네트워크/Cloudflare 리소스/SSH 키 파일/Ansible 자동 생성 파일이 제거된다.