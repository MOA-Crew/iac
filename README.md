# MOA Infrastructure (IaC)

MOA 서비스의 인프라를 코드로 관리하는 모노레포다. 역할을 둘로 나눠 운영한다.

| 도구 | 책임 |
|---|---|
| **Terraform** | 인프라 프로비저닝 — VPC / EC2 / RDS / S3 / Cloudflare DNS·Tunnel |
| **Ansible** | 서버 OS·런타임 구성 — Docker, zram, Redis, cloudflared, pgvector |

**인프라 변경은 GitOps로 적용한다.** `terraform/**` 를 고쳐 PR을 올리면 CI가 `plan` 을 돌려 PR 코멘트로 보여주고, `dev` 머지 시 수동 승인 게이트를 거쳐 `apply` 된다. 인증은 GitHub OIDC라 **로컬에 AWS/Terraform 키를 둘 필요가 없다.**

> 📐 아키텍처 상세 → [docs/architecture.md](./docs/architecture.md) · 🔐 CI/CD·인증 흐름 → [docs/cicd-and-auth.md](./docs/cicd-and-auth.md) · 🤖 에이전트 작업 가이드 → [CLAUDE.md](./CLAUDE.md)

> **네이밍**: 프로젝트 브랜드는 **MOA**다. 다만 일부 AWS 리소스는 초기 SW중심대학 계정 셋업 때 굳은 `sw-hub` / `swhub` prefix를 그대로 쓴다(state 버킷·IAM role·RDS db/user 등 — 운영 중이라 개명하려면 재생성이 필요). 앱·Cloudflare 레이어는 `moa`. AWS 리소스 prefix의 `moa` 통일은 별도 마이그레이션 작업으로 분리한다.

---

## 아키텍처 (dev)

외부 트래픽은 EC2 포트로 직접 들어오지 않는다. 전부 **Cloudflare Tunnel** 을 통해 들어오고, EC2는 인바운드 앱 포트를 열지 않는다.

```text
                 인터넷
                   │ https://moa.yeoun.org
                   ▼
          ┌─────────────────┐
          │  Cloudflare      │  엣지 TLS + Zero Trust Tunnel
          └────────┬────────┘
                   │ (아웃바운드 터널 연결, 인바운드 개방 없음)
   ┌───────────────┼──────────────────────────────────┐
   │ VPC 10.10.0.0/16                                  │
   │   ┌──────────────── public subnet ×2 ──────────┐ │
   │   │  EC2 (t3.small, Ubuntu 22.04, IMDSv2)       │ │
   │   │   ├ moa-be (Docker)        :8080            │ │
   │   │   ├ cloudflared (Docker)   → 터널 connector │ │
   │   │   └ redis (Docker)         127.0.0.1:6379   │ │
   │   └───────────────────┬─────────────────────────┘ │
   │                       │ EC2 SG에서만 5432 허용      │
   │   ┌──────────── private subnet ×2 ─────────────┐  │
   │   │  RDS PostgreSQL (비공개, 암호화, pgvector)  │  │
   │   └─────────────────────────────────────────────┘  │
   └────────────────────────────────────────────────────┘
        EC2 → S3 : instance profile (키 없음)
```

| 구성요소 | 내용 |
|---|---|
| **네트워크** | VPC `10.10.0.0/16`, public ×2 / private ×2 subnet, IGW (private는 NAT 미사용) |
| **EC2** | `t3.small` 1대, Ubuntu 22.04, **IMDSv2 강제**, SSH 키 Terraform 자동 생성, S3용 instance profile |
| **RDS** | PostgreSQL, private subnet, **EC2 SG에서만 접근**, gp3 암호화, 비공개(`publicly_accessible=false`) |
| **S3** | dev용 버킷 (EC2 instance profile로 접근) |
| **Cloudflare** | DNS record + Zero Trust Tunnel을 Terraform으로 관리, ingress → `localhost:8080` |
| **Redis** | 비용 절감 위해 ElastiCache 대신 EC2 내부 Docker Compose (`127.0.0.1:6379`) |
| **Terraform state** | **S3 원격 백엔드** (버전관리·암호화·퍼블릭 차단, S3 네이티브 락파일). 로컬 state 아님 |

---

## 레포 구조

```text
.
├── .github/workflows/
│   ├── terraform.yml     # GitOps: PR→plan, dev 머지→apply(승인 게이트)
│   └── validate.yml      # fmt/validate 검증
├── terraform/
│   ├── environments/dev/ # dev 엔트리포인트 (backend·provider·vars·cloudflare·iam·s3)
│   └── modules/          # network · ec2 · rds · s3 (재사용 모듈)
├── ansible/
│   ├── inventories/dev/  # hosts.yml, secrets.yml은 terraform apply 시 자동 생성
│   ├── playbooks/        # bootstrap.yml · site.yml
│   └── roles/            # common · ram_optimization · docker · redis · cloudflared · postgres
├── docs/                 # architecture.md · cicd-and-auth.md
└── tools/install-dependencies.sh
```

---

## 인프라 변경 — GitOps (메인 경로)

로컬에서 `apply` 하지 않는다. GitHub에 올리면 CI가 OIDC로 AWS에 인증해 처리한다.

```text
terraform/** 수정 → PR
   → GitHub Actions가 OIDC로 임시 AWS 자격증명 발급 → terraform plan → PR 코멘트
        │ (리뷰)
        ▼
dev 머지 → terraform apply 시도 → 'dev-apply' 환경 수동 승인 → apply
```

- **인증**: GitHub OIDC → IAM role (저장된 액세스 키 없음)
- **트리거**: `terraform/**`, `.github/workflows/terraform.yml` 변경 시
- **필요한 Repo Secrets**: `CLOUDFLARE_API_TOKEN`, `TF_VAR_CLOUDFLARE_ACCOUNT_ID`, `TF_VAR_CLOUDFLARE_ZONE_NAME`, `TF_VAR_CLOUDFLARE_HOSTNAME`
- ⚠️ PR에 **머지 충돌**이 있으면 GitHub가 merge ref를 못 만들어 워크플로가 트리거되지 않는다. 충돌부터 해소할 것.

> 일상 작업은 **PR → plan 확인 → 머지 → 승인** 이게 전부다. 흐름·자격증명 위치 상세는 [docs/cicd-and-auth.md](./docs/cicd-and-auth.md).

---

## 로컬에서 직접 다루기 (선택 — plan / import / 디버깅)

대부분 GitOps로 충분하다. 로컬 plan·state import·Ansible 실행에만 도구가 필요하다.

```bash
# 1. 도구 설치
./tools/install-dependencies.sh   # Ubuntu/WSL: AWS CLI v2, Terraform, Ansible(+collections)
# macOS: brew install awscli terraform ansible && ansible-galaxy collection install community.general community.postgresql

# 2. 인증 (state가 S3에 있어 해당 버킷 접근 권한 필요)
aws configure

# 3. Cloudflare 변수 주입 (코드에 하드코딩 금지)
export CLOUDFLARE_API_TOKEN=...
export TF_VAR_cloudflare_account_id=...
export TF_VAR_cloudflare_zone_name=...
export TF_VAR_cloudflare_hostname=...

# 4. plan
cd terraform/environments/dev
terraform init      # S3 원격 백엔드 연결 (로컬 state 생성 X)
terraform plan
```

출력값/키 조회 (state = S3):

```bash
terraform output                          # EC2 IP, RDS endpoint 등
terraform output -raw rds_password        # RDS 비밀번호
terraform output -raw rds_tunnel_command  # 노트북→RDS SSH 포트포워딩 명령
```

> CI의 `apply` 는 일회용 러너에서 돌아 SSH key·Ansible 인벤토리 같은 로컬 산출물이 남지 않는다. 로컬에서 필요하면 위 `terraform output` 으로 조회한다.

---

## 서버 구성 (Ansible)

Ansible은 아직 Terraform CI에 포함되지 않는다(로컬/수동 실행). `ansible/` 디렉토리에서 실행해야 `ansible.cfg` 가 자동 인식된다.

```bash
cd ansible
ansible -m ping all
export MOA_PUBLIC_HOSTNAME=...
export CLOUDFLARED_TUNNEL_TOKEN=...
ansible-playbook playbooks/site.yml
```

| role | 역할 |
|---|---|
| **common** | 기본 패키지, timezone (Asia/Seoul) |
| **ram_optimization** | zram-tools + `vm.swappiness` 튜닝 (작은 인스턴스용) |
| **docker** | Docker CE + Compose plugin, 로그 회전 제한 |
| **redis** | EC2 내부 Redis Compose (`127.0.0.1:6379`) |
| **cloudflared** | Cloudflare Tunnel connector Compose |
| **postgres** | RDS에 pgvector 확장 설치 |

특정 role만 실행: `ansible-playbook playbooks/site.yml --tags redis`

---

## 정리 (destroy)

`destroy` 는 GitOps에 없다. 의도적으로 로컬에서만 수행한다(주의).

```bash
cd terraform/environments/dev
terraform destroy   # EC2/RDS/S3/네트워크/Cloudflare/SSH 키·Ansible 자동생성 파일 제거
```
