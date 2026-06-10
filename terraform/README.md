# Terraform

재사용 가능한 모듈(`modules/`)과 환경별 엔트리포인트(`environments/`)로 구성된다.
모든 모듈은 실제 AWS 리소스를 생성한다(placeholder 아님).

## 모듈

| 모듈 | 생성 리소스 |
|---|---|
| `modules/network` | VPC, public/private subnet ×2, IGW, route table (private는 NAT 미사용) |
| `modules/ec2` | Ubuntu 22.04 EC2, SG, ED25519 키페어(자동 생성), **IMDSv2 강제**, instance profile 연결 |
| `modules/rds` | PostgreSQL 인스턴스, subnet group, SG(EC2 SG에서만 인바운드), gp3 암호화 |
| `modules/s3` | dev용 S3 버킷 (`for_each` 로 용도별 생성) |

## 환경

- `environments/dev` — dev 엔트리포인트. 모듈 호출 + provider/backend/변수 + Cloudflare(`cloudflare.tf`)·IAM(`iam.tf`)·S3(`s3.tf`)·Ansible 연동(`ansible.tf`).

| 파일 | 역할 |
|---|---|
| `backend.tf` | S3 원격 state 백엔드 (S3 네이티브 락파일, DynamoDB 불필요) |
| `providers.tf` / `versions.tf` | AWS·Cloudflare provider, 버전 핀 |
| `variables.tf` / `terraform.tfvars.example` | 입력 변수와 예시값 |
| `iam.tf` | EC2 instance profile (app role → S3 접근, 키 없음) |
| `cloudflare.tf` | Zero Trust Tunnel + DNS record |
| `ansible.tf` | `terraform apply` 시 Ansible 인벤토리/시크릿 파일 자동 생성 |
| `outputs.tf` | EC2 IP, RDS endpoint/비번, 터널 토큰, RDS SSH 터널 명령 등 |

## state & 인증

- **state**: S3 원격 백엔드 `sw-hub-dev-tfstate-<account_id>` (버전관리·암호화·퍼블릭 차단). 로컬 state 아님.
- **CI 인증**: GitHub OIDC → IAM role (영구 액세스 키 없음). 상세는 [../docs/cicd-and-auth.md](../docs/cicd-and-auth.md).

## 드리프트 처리 (`ignore_changes`)

기존/외부 리소스를 import해 관리에 편입하며 둔 안전장치.

- **EC2 `ami`** — `most_recent` 라 새 AMI 출시 시 인스턴스 교체를 막기 위해 무시.
- **RDS `engine_version`** — 마이너 자동 업그레이드를 terraform이 되돌리려다 실패하는 것 방지.
- **Cloudflare 터널 `secret`** — import 후 API로 재조회 불가라 매 apply 재생성(라이브 끊김) 방지.

> 네이밍: 리소스 prefix는 변수 `project_name`(현재 default `sw-hub`)에서 파생된다. 브랜드(MOA)와의 차이 및 통일 계획은 루트 [README](../README.md)의 네이밍 노트 참고.
