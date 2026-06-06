# SW-Hub IaC

SW-Hub 인프라 모노레포. 역할 분리로 운영한다.

- **Terraform**: 네트워크 / EC2 / RDS / S3 / Cloudflare DNS·Tunnel 등 **인프라 프로비저닝**
- **Ansible**: 생성된 서버의 **OS·런타임 구성 관리** (Docker, zram, Redis, cloudflared, pgvector 등)

현재 dev 환경은 EC2 앱 서버 + RDS PostgreSQL + EC2 로컬 Redis + Cloudflare Tunnel 진입 구조다. EC2의 앱 포트는 직접 공개하지 않고, 공개 HTTPS 트래픽은 Cloudflare Tunnel을 통해 들어온다.

**인프라 변경은 GitOps로 적용한다.** `terraform/**` 를 수정해 PR을 올리면 CI가 자동으로 `plan` 을 돌려 PR 코멘트로 보여주고, dev 브랜치에 머지하면 수동 승인 게이트를 거쳐 `apply` 된다. 인증은 GitHub OIDC라 **로컬에 Terraform/AWS 키를 깔지 않아도 된다.**

> 설계 원칙·아키텍처 배경은 [CLAUDE.md](./CLAUDE.md), **CI/CD·인증 흐름 상세는 [docs/cicd-and-auth.md](./docs/cicd-and-auth.md)** 참고.

## 구조

```text
.
├── .github/workflows/
│   └── terraform.yml         # GitOps 파이프라인: PR→plan, dev 머지→apply(승인 게이트)
├── terraform/
│   ├── environments/dev/     # dev 엔트리포인트
│   │   ├── backend.tf        # S3 원격 state 백엔드 (락파일)
│   │   ├── *.tf              # AWS/Cloudflare provider, vars, ansible 연동
│   └── modules/
│       ├── network/          # VPC, public/private subnet × 2, IGW, route table
│       ├── ec2/              # AMI, key pair (자동 생성), SG, 인스턴스, IMDSv2 강제
│       ├── rds/              # subnet group, SG (EC2 SG만 허용), PostgreSQL
│       └── s3/               # dev용 S3 bucket
├── ansible/
│   ├── ansible.cfg           # inventory/roles 경로 등 — 이 디렉토리에서 실행
│   ├── inventories/dev/      # hosts.yml, secrets.yml은 terraform apply 시 자동 생성
│   ├── playbooks/site.yml
│   └── roles/                # common, ram_optimization, docker, redis, cloudflared, postgres
├── docs/                     # architecture.md, cicd-and-auth.md
└── tools/
    └── install-dependencies.sh  # (로컬 운영 시) AWS CLI, Terraform, Ansible 일괄 설치
```

## 현재 dev 구성 요약

- **AWS**: VPC / EC2 app node / RDS PostgreSQL / S3
- **Terraform state**: **S3 원격 백엔드** `sw-hub-dev-tfstate-<account_id>` (버전관리·암호화·퍼블릭 차단, S3 네이티브 락파일). 로컬 state 아님.
- **Redis**: 비용 절감을 위해 ElastiCache 대신 EC2 내부 Docker Compose Redis 사용
  - 기본 바인딩: `127.0.0.1:6379`, 외부 공개 금지
- **Cloudflare**: DNS record + Zero Trust Tunnel을 Terraform으로 관리
- **cloudflared**: Ansible role이 EC2에서 Docker Compose 서비스로 실행

## 배포 방식: GitOps (메인 경로)

인프라 변경은 **로컬에서 `apply` 하지 않는다.** GitHub에 올리면 CI가 OIDC로 AWS에 인증해 처리한다.

```text
terraform/** 수정 → PR
   → GitHub Actions가 OIDC로 임시 AWS 자격증명 발급
   → terraform plan → 결과를 PR 코멘트로 게시
       │
       ▼  (리뷰 후)
dev 브랜치 머지(push)
   → terraform apply 시도
   → GitHub Environment 'dev-apply' 수동 승인 게이트
   → 승인하면 apply 실행
```

- **인증**: GitHub OIDC → IAM role `sw-hub-dev-gha-terraform` (저장된 액세스 키 없음)
- **트리거 경로**: `terraform/**`, `.github/workflows/terraform.yml` 변경 시
- **승인 게이트**: `dev-apply` 환경 (reviewer 승인 + dev 브랜치 제한)
- **필요한 Repository Secrets**: `CLOUDFLARE_API_TOKEN`, `TF_VAR_CLOUDFLARE_ACCOUNT_ID`, `TF_VAR_CLOUDFLARE_ZONE_NAME`, `TF_VAR_CLOUDFLARE_HOSTNAME`
- ⚠️ PR에 **머지 충돌**이 있으면 GitHub가 merge ref를 못 만들어 워크플로가 트리거되지 않는다. 충돌부터 해소할 것.

> 일상 작업은 **PR 올리고 → plan 확인 → 머지 → 승인** 이게 전부다. 로컬에 도구를 깔 필요 없다. 흐름 전체와 자격증명 위치는 [docs/cicd-and-auth.md](./docs/cicd-and-auth.md).

## 로컬에서 직접 다루기 (선택 — plan / import / Ansible / 디버깅)

대부분 GitOps로 충분하지만, 로컬 plan·state import·Ansible 실행에는 도구가 필요하다.

### 1. 도구 설치

```bash
./tools/install-dependencies.sh          # Ubuntu/WSL: AWS CLI v2, Terraform, Ansible(+collections)
# macOS: brew install awscli terraform ansible && ansible-galaxy collection install community.general community.postgresql
```

### 2. AWS 인증

```bash
aws configure   # state가 S3에 있으므로 해당 버킷 접근 권한 필요
```

### 3. Cloudflare 변수 (코드에 하드코딩 금지)

```bash
export CLOUDFLARE_API_TOKEN=...
export TF_VAR_cloudflare_account_id=...
export TF_VAR_cloudflare_zone_name=...
export TF_VAR_cloudflare_hostname=...
```

### 4. 로컬 plan / import

```bash
cd terraform/environments/dev
terraform init     # S3 원격 백엔드에 연결 (로컬 state 생성 X)
terraform plan
```

- 기존(수동/외부 생성) 리소스를 state로 편입할 때는 `terraform import`.
- Cloudflare 터널/DNS import 절차와 드리프트(`ignore_changes`) 처리는 [docs/cicd-and-auth.md](./docs/cicd-and-auth.md) 의 "드리프트 처리" 참고.

### 5. 출력값 / 키 조회 (state = S3)

```bash
terraform output                              # EC2 IP, RDS endpoint 등
terraform output -raw rds_password            # RDS 비밀번호
terraform output -raw rds_tunnel_command      # 노트북→RDS SSH 포트포워딩 명령
```

> CI의 `apply` 는 일회용 러너에서 돌기 때문에, SSH private key(`sw-hub-dev.pem`)·Ansible 인벤토리 같은 로컬 파일 산출물은 **로컬에 남지 않는다.** 로컬에서 필요하면 위 `terraform output` 으로 조회하거나, 로컬에서 `terraform apply`(또는 refresh)를 한 번 돌려 파일을 생성한다.

## 서버 구성 (Ansible)

Ansible은 아직 Terraform CI 파이프라인에 포함되지 않는다(로컬/수동 실행). `ansible/` 디렉토리에서 실행해야 `ansible.cfg` 가 자동 인식된다.

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

## 정리 (destroy)

`destroy` 는 GitOps 파이프라인에 없다. 의도적으로 로컬에서만 수행한다(주의).

```bash
cd terraform/environments/dev
terraform destroy
```

EC2/RDS/S3/네트워크/Cloudflare 리소스/SSH 키 파일/Ansible 자동 생성 파일이 제거된다.
