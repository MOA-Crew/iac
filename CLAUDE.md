# CLAUDE.md

Claude Code(또는 다른 코딩 에이전트)가 이 레포에서 작업할 때 빠르게 맥락을 잡기 위한 안내서.

## 이 레포가 하는 일

**MOA 서비스의 인프라 코드 저장소.** 한 레포에서 두 책임을 분리 운영한다.

- `terraform/` — 인프라 프로비저닝 (VPC/EC2/RDS/S3/Cloudflare)
- `ansible/` — 생성된 서버의 OS·런타임 구성 (docker/redis/cloudflared/pgvector 등)

> ⚠️ 이 레포는 **이미 dev 인프라가 실제로 떠서 운영 중**이다. "초기 골조/placeholder" 단계가 아니다. 변경은 운영 중인 리소스에 영향을 줄 수 있으니 신중히 다룬다. 전체 그림은 [README.md](./README.md)와 [docs/architecture.md](./docs/architecture.md)를 먼저 읽을 것.

## 현재 구성 (prod + dev) 요약

**공유 인프라 위에 앱 박스 2대** 모델. 단일 terraform 스택(`environments/dev/`)이 둘 다 관리한다.

- **네트워크**: 공유 VPC `10.10.0.0/16`(`sw-hub-dev-*`), public/private subnet ×2, IGW (private NAT 미사용).
- **EC2 2대**: `moa-prod`(t3.small, moa.yeoun.org) + `moa-dev`(t3.micro, dev-moa.yeoun.org). Ubuntu 22.04, IMDSv2 강제. 각 박스에서 `moa-be`·`cloudflared`·`redis` 구동. 박스별 SSH 키.
- **RDS**: PostgreSQL **인스턴스 1개 공유**(`moa-prod-db`), 내부 database `moa_prod`(prod)·`moa_dev`(dev, Ansible 생성). private, 두 박스 SG에서만 접근, pgvector.
- **S3**: 앱 버킷 `sw-hub-dev-*` (EC2 instance profile 접근).
- **Cloudflare**: 환경별 Zero Trust Tunnel + DNS 2벌(`moa-prod`/`moa-dev`)을 Terraform `for_each` 로 관리. 외부 진입 `https://moa.yeoun.org`(prod)·`https://dev-moa.yeoun.org`(dev).
- **배포**: Terraform GitOps(단일 스택, `dev` 머지→`dev-apply` 승인→apply). Ansible은 브랜치로 박스 선택(`dev`→dev_app/`dev-apply`, `main`→prod_app/`prod-apply`). CI는 GitHub OIDC.
- **state**: S3 원격 백엔드 `sw-hub-dev-tfstate-*` (단일 키 `dev/terraform.tfstate`, 네이티브 락파일).
- **네이밍**: EC2·RDS·Cloudflare 터널만 `moa-*`. VPC·IAM·S3·state·CI role은 `sw-hub-*` 유지(혼재는 의도, [네이밍](#네이밍) 참고).

## 작업 원칙

### 1. Terraform과 Ansible 책임을 섞지 말 것
- Terraform: 리소스 생성/선언 (서버를 몇 대 만들지).
- Ansible: 생성된 서버 구성 (서버에 Docker를 설치할지).

### 2. 비밀값을 코드/state에 노출하지 말 것
- API 키·SSH private key·비밀번호·토큰·실서비스 민감 endpoint를 하드코딩 금지. 예시는 `.example` 로.
- Cloudflare 토큰/터널 시크릿은 환경변수·GH Secret·Ansible Vault로만 주입.

### 3. 운영 중 리소스를 깨지 않게
- `apply` 는 항상 `dev-apply` 승인 게이트를 거친다. 자동 apply 없음.
- `ignore_changes`(EC2 `ami`, RDS `engine_version`, Cloudflare 터널 `secret`)는 라이브 끊김 방지용 의도된 장치다 — 함부로 제거하지 말 것. 배경은 [docs/cicd-and-auth.md](./docs/cicd-and-auth.md) "드리프트 처리".
- 리소스 **이름 변경**(예: `project_name` prefix)은 destroy/재생성을 유발한다. 단순 리네이밍처럼 다루지 말 것 — 별도 마이그레이션으로 계획.

### 4. prod/dev 분리 모델 이해
- prod·dev는 **별도 스택이 아니라** 단일 스택의 앱 박스 2대(`module.ec2_prod`/`module.ec2_dev`) + 공유 RDS의 database 2개로 구현된다. 무거운 자원(VPC/RDS 인스턴스)은 공유.
- 박스 prefix(`var.app_project_name`=`moa`)와 공유 인프라 prefix(`var.project_name`=`sw-hub`)가 다르다. 새 박스/환경 추가는 `module.ec2_*` 호출과 `cloudflare_edges` 맵, ansible 그룹을 함께 늘린다.

### 5. 문서는 한국어 중심, 커밋은 영어 컨벤션
- README 등 핵심 문서는 한국어. 커밋 메시지는 `feat:`/`fix:`/`docs:` 컨벤션 유지.

## 변경 시 추천 순서

1. README·architecture·해당 모듈을 읽고 현재 상태/의도를 파악한다.
2. 변경이 Terraform인지 Ansible인지 경계를 정한다.
3. 최소 변경으로 적용하고, **`terraform fmt` + `validate`** (CI `validate.yml`)를 통과시킨다.
4. 운영 영향(재생성 여부)을 `plan` 으로 먼저 확인한다.
5. 관련 문서도 같이 갱신한다 (문서가 실제와 어긋나지 않게).

## 네이밍

브랜드는 **MOA**. **EC2·RDS·Cloudflare 터널은 `moa-*`**(보존 데이터 없어 새로 생성). **VPC·IAM app role·S3·tfstate 버킷·CI role(`sw-hub-dev-gha-terraform`)·OIDC는 `sw-hub-*` 유지** — CI role IAM 권한이 `sw-hub-*` 스코프라 IAM까지 moa로 바꾸려면 admin 작업 필요, 플러밍이라 의도적으로 둔다. 따라서 `moa-prod`/`moa-dev` EC2가 `sw-hub-dev-vpc` 안에 있는 혼재는 **버그가 아니라 의도**. 상세는 [README](./README.md)의 네이밍 노트.
