# CLAUDE.md

Claude Code(또는 다른 코딩 에이전트)가 이 레포에서 작업할 때 빠르게 맥락을 잡기 위한 안내서.

## 이 레포가 하는 일

**MOA 서비스의 인프라 코드 저장소.** 한 레포에서 두 책임을 분리 운영한다.

- `terraform/` — 인프라 프로비저닝 (VPC/EC2/RDS/S3/Cloudflare)
- `ansible/` — 생성된 서버의 OS·런타임 구성 (docker/redis/cloudflared/pgvector 등)

> ⚠️ 이 레포는 **이미 dev 인프라가 실제로 떠서 운영 중**이다. "초기 골조/placeholder" 단계가 아니다. 변경은 운영 중인 리소스에 영향을 줄 수 있으니 신중히 다룬다. 전체 그림은 [README.md](./README.md)와 [docs/architecture.md](./docs/architecture.md)를 먼저 읽을 것.

## 현재 구성 (dev) 요약

- **네트워크**: VPC `10.10.0.0/16`, public/private subnet ×2, IGW (private NAT 미사용).
- **EC2**: `t3.small` 1대, Ubuntu 22.04, IMDSv2 강제. 위에서 `moa-be`·`cloudflared`·`redis` 컨테이너 구동.
- **RDS**: PostgreSQL, private, EC2 SG에서만 접근, pgvector.
- **S3**: dev 버킷 (EC2 instance profile 접근).
- **Cloudflare**: Zero Trust Tunnel + DNS를 Terraform이 관리. 외부 진입은 `https://moa.yeoun.org` 만.
- **배포**: Terraform GitOps (PR→plan, dev 머지→승인 게이트→apply), CI는 GitHub OIDC.
- **state**: S3 원격 백엔드 (네이티브 락파일).

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

### 4. 환경 확장을 염두에 둘 것
- 지금은 `dev`만 있다. `stage`/`prod` 추가가 쉽도록 모듈/변수 구조를 유지한다.

### 5. 문서는 한국어 중심, 커밋은 영어 컨벤션
- README 등 핵심 문서는 한국어. 커밋 메시지는 `feat:`/`fix:`/`docs:` 컨벤션 유지.

## 변경 시 추천 순서

1. README·architecture·해당 모듈을 읽고 현재 상태/의도를 파악한다.
2. 변경이 Terraform인지 Ansible인지 경계를 정한다.
3. 최소 변경으로 적용하고, **`terraform fmt` + `validate`** (CI `validate.yml`)를 통과시킨다.
4. 운영 영향(재생성 여부)을 `plan` 으로 먼저 확인한다.
5. 관련 문서도 같이 갱신한다 (문서가 실제와 어긋나지 않게).

## 네이밍

브랜드는 **MOA**. 일부 AWS 리소스는 초기 SW중심대학 계정 셋업의 `sw-hub`/`swhub` prefix를 유지한다(개명=재생성이라 보류 중). 새 prose/문서는 MOA로 통일한다. 상세는 [README](./README.md)의 네이밍 노트.
