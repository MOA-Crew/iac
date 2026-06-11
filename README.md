# MOA Infrastructure (IaC)

MOA 서비스의 인프라를 코드로 관리하는 모노레포다. 역할을 둘로 나눠 운영한다.

| 도구 | 책임 |
|---|---|
| **Terraform** | 인프라 프로비저닝 — VPC / EC2 / RDS / S3 / Cloudflare DNS·Tunnel |
| **Ansible** | 서버 OS·런타임 구성 — Docker, zram, cloudflared, pgvector |

**인프라 변경은 GitOps로 적용한다.** `terraform/**` 를 고쳐 PR을 올리면 CI가 `plan` 을 돌려 PR 코멘트로 보여주고, `dev` 머지 시 수동 승인 게이트를 거쳐 `apply` 된다. 인증은 GitHub OIDC라 **로컬에 AWS/Terraform 키를 둘 필요가 없다.**

> 📐 아키텍처 상세 → [docs/architecture.md](./docs/architecture.md) · 🔐 CI/CD·인증 흐름 → [docs/cicd-and-auth.md](./docs/cicd-and-auth.md) · 🤖 에이전트 작업 가이드 → [CLAUDE.md](./CLAUDE.md)

> **네이밍**: 프로젝트 브랜드는 **MOA**다. **EC2·RDS는 `moa-*`** 로 새로 만들었고(보존할 데이터가 없어 깨끗이 재생성), Cloudflare 터널도 `moa-prod`/`moa-dev`다. 반면 **VPC·IAM app role·S3(앱/state 버킷)·CI role(`sw-hub-dev-gha-terraform`)·OIDC는 `sw-hub` 유지** — CI role의 IAM 권한 스코프가 `sw-hub-*`라 IAM까지 moa로 바꾸려면 admin 작업이 필요하고, 그 플러밍은 거의 안 보여서 의도적으로 둔다(혼재는 의도된 부채). 따라서 `moa-prod`/`moa-dev` EC2가 `sw-hub-dev-vpc` 안에 산다.

---

## 아키텍처 (prod + dev)

**공유 인프라(VPC·RDS 인스턴스·S3·IAM) 위에 앱 박스 2대**를 둔다. 무거운 stateful 자원은 공유해 비용을 아끼고, 환경은 박스·database·터널·도메인으로 분리한다. 외부 트래픽은 EC2 포트로 직접 들어오지 않고 전부 **Cloudflare Tunnel** 을 통한다.

```text
        인터넷
          │  https://moa.yeoun.org        https://dev-moa.yeoun.org
          ▼                                          ▼
   ┌──────────────┐                          ┌──────────────┐
   │  Cloudflare  │  터널 moa-prod            │  Cloudflare  │  터널 moa-dev
   └──────┬───────┘                          └──────┬───────┘
          │ (아웃바운드 터널, 인바운드 개방 없음)        │
   ┌──────┼─────────────────────────────────────────┼──────────────┐
   │ VPC sw-hub-dev-vpc 10.10.0.0/16                 │              │
   │   ┌── public subnet ×2 ──────────────────────────────────────┐ │
   │   │  moa-prod (t3.small)          moa-dev (t3.micro)          │ │
   │   │   ├ moa-be :8080               ├ moa-be :8080             │ │
   │   │   ├ cloudflared → moa-prod     ├ cloudflared → moa-dev    │ │
   │   │   └ redis via BE compose       └ redis via BE compose     │ │
   │   └──────────────┬───────────────────────────┬───────────────┘ │
   │                  │ 두 박스 SG에서만 5432 허용  │                 │
   │   ┌── private subnet ×2 ──────────────────────────────────────┐ │
   │   │  RDS PostgreSQL  moa-prod-db (공유)                        │ │
   │   │    ├ database moa_prod  (prod)                            │ │
   │   │    └ database moa_dev   (dev)                             │ │
   │   └────────────────────────────────────────────────────────────┘ │
   └────────────────────────────────────────────────────────────────┘
        EC2 → S3 : instance profile (키 없음)
```

| 구성요소 | 내용 |
|---|---|
| **네트워크** | 공유 VPC `10.10.0.0/16`(`sw-hub-dev-*`), public ×2 / private ×2 subnet, IGW |
| **EC2** | `moa-prod`(t3.small, moa.yeoun.org) + `moa-dev`(t3.micro, dev-moa.yeoun.org). Ubuntu 22.04, **IMDSv2 강제**, 박스별 SSH 키, S3용 instance profile(공유 sw-hub) |
| **RDS** | PostgreSQL **인스턴스 1개 공유**(`moa-prod-db`), 내부 database `moa_prod`/`moa_dev`. private, 두 박스 SG에서만 접근, gp3 암호화 |
| **S3** | 앱 버킷 (`sw-hub-dev-*`, EC2 instance profile로 접근) |
| **Cloudflare** | 환경별 터널·DNS record 2벌(`moa-prod`/`moa-dev`)을 Terraform `for_each` 로 관리 |
| **Redis** | 박스마다 **BE compose**가 앱과 함께 기동 (앱과 같은 docker 네트워크, 서비스명 `redis`로 접속, 호스트 포트 비노출) |
| **Terraform state** | **S3 원격 백엔드** `sw-hub-dev-tfstate-*` (단일 스택, 키 `dev/terraform.tfstate`) |

---

## 레포 구조

```text
.
├── .github/workflows/
│   ├── cd-terraform.yml  # GitOps: PR→plan, dev 머지→apply(승인 게이트)
│   ├── cd-ansible.yml    # Ansible CD: PR→syntax check, dev 머지→site.yml 실행(승인 게이트)
│   └── validate.yml      # fmt/validate 검증
├── terraform/
│   ├── environments/dev/ # dev 엔트리포인트 (backend·provider·vars·cloudflare·iam·s3)
│   └── modules/          # network · ec2 · rds · s3 (재사용 모듈)
├── ansible/
│   ├── inventories/dev/  # hosts.yml, secrets.yml은 terraform apply 시 자동 생성
│   ├── playbooks/        # bootstrap.yml · site.yml
│   └── roles/            # common · ram_optimization · docker · cloudflared · postgres
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
- **트리거**: `terraform/**`, `.github/workflows/cd-terraform.yml` 변경 시. 단일 스택이라 `dev` 머지→`dev-apply` 승인→apply.
- **필요한 Repo Secrets**: `CLOUDFLARE_API_TOKEN`, `TF_VAR_CLOUDFLARE_ACCOUNT_ID`, `TF_VAR_CLOUDFLARE_ZONE_NAME`, `TF_VAR_CLOUDFLARE_HOSTNAME_PROD`(moa.yeoun.org), `TF_VAR_CLOUDFLARE_HOSTNAME_DEV`(dev-moa.yeoun.org)
- ⚠️ PR에 **머지 충돌**이 있으면 GitHub가 merge ref를 못 만들어 워크플로가 트리거되지 않는다. 충돌부터 해소할 것.

> 일상 작업은 **PR → plan 확인 → 머지 → 승인** 이게 전부다. 흐름·자격증명 위치 상세는 [docs/cicd-and-auth.md](./docs/cicd-and-auth.md).

### 서버 구성 변경 — Ansible CD

`ansible/**` 수정도 같은 GitOps 흐름을 탄다 (`.github/workflows/cd-ansible.yml`). 박스가 둘이라 브랜치로 대상을 가른다.

- **PR**: playbook 문법 체크만 (서버 접속 없음)
- **`dev` 머지**: `dev-apply` 승인 → `site.yml --limit dev_app` (dev 박스)
- **`main` 머지**: `prod-apply` 승인 → `site.yml --limit prod_app` (prod 박스)
- **환경(Environment) 시크릿** (`dev-apply`/`prod-apply` 각각): `ANSIBLE_SSH_PRIVATE_KEY`(박스 pem), `TF_VAR_CLOUDFLARE_HOSTNAME`(박스 hostname), `CLOUDFLARED_TUNNEL_TOKEN`(박스 터널 토큰)
- **Repo 시크릿(공유)**: `POSTGRES_RDS_PASSWORD`(공유 RDS master)

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
export TF_VAR_cloudflare_hostname_prod=...   # moa.yeoun.org
export TF_VAR_cloudflare_hostname_dev=...    # dev-moa.yeoun.org

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
| **cloudflared** | Cloudflare Tunnel connector Compose |
| **postgres** | 공유 RDS에 환경 database(moa_prod/moa_dev) 보장 + pgvector 확장 설치 |

박스 선택은 그룹으로: `ansible-playbook playbooks/site.yml --limit dev_app` (또는 `prod_app`). 특정 role만: `... --tags cloudflared`.

---

## 정리 (destroy)

`destroy` 는 GitOps에 없다. 의도적으로 로컬에서만 수행한다(주의).

```bash
cd terraform/environments/dev
terraform destroy   # EC2/RDS/S3/네트워크/Cloudflare/SSH 키·Ansible 자동생성 파일 제거
```
