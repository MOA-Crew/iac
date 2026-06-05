# CI/CD & 인증 흐름 (dev)

Terraform GitOps 파이프라인과 전체 인증/자격증명 흐름을 정리한 문서.

핵심 원칙: **인프라 배포 경로(CI → AWS)에 영구 액세스 키가 0개.** GitHub ↔ AWS 신뢰관계(OIDC)로 매 실행마다 단기 토큰을 발급받는다.

---

## 1. 인프라 배포 파이프라인 (이 레포)

```
 [개발자] PR 또는 dev 머지 (MOA-Crew/iac)
     │
     ▼
 [GitHub Actions 러너]
     │  ① 러너가 GitHub OIDC provider에 단기 JWT 요청
     │     token.actions.githubusercontent.com
     │     클레임: sub=repo:MOA-Crew/iac:*, aud=sts.amazonaws.com
     ▼
 [AWS STS] AssumeRoleWithWebIdentity (JWT 제시)
     │  ② 검증: JWT 서명(등록된 OIDC provider) + aud + sub(신뢰정책)
     │  ③ 통과 → role(sw-hub-dev-gha-terraform)의 임시 자격증명 발급(~1h)
     ▼
 [Terraform]
     ├─ AWS 리소스(ec2/rds/s3/iam) : OIDC 임시 자격증명
     ├─ S3 state 백엔드            : OIDC 임시 자격증명
     └─ Cloudflare 리소스          : CLOUDFLARE_API_TOKEN (GH Secret)
     │
     ├─ PR 이벤트 → plan만 → 결과를 PR 코멘트
     └─ dev push  → apply 시도
            │
            ▼
     [GitHub Environment: dev-apply]  ← ④ 수동 승인 게이트
            │
            ▼
     terraform apply → AWS/Cloudflare 반영
```

1~3 단계에 저장된 비밀번호/액세스 키가 없다. 신뢰관계로 매번 즉석 발급.

### 워크플로 트리거
- **PR (`pull_request`)**: `terraform plan` → 결과를 PR 코멘트. (읽기/계획만)
- **dev 머지 (`push: dev`)**: `terraform apply` → `dev-apply` 환경 승인 후 실행.
- 경로 필터: `terraform/**`, `.github/workflows/terraform.yml` 변경 시에만 동작.
- ⚠️ PR에 머지 충돌이 있으면 GitHub이 merge ref를 못 만들어 **워크플로 자체가 트리거되지 않는다.** 충돌부터 해소할 것.

---

## 2. 자격증명/시크릿 위치

| 자격증명 | 위치 | 용도 | 형태 |
|---|---|---|---|
| GitHub OIDC 신뢰 | AWS IAM OIDC provider + role 신뢰정책 | CI → AWS 인증 | 키 없음(페더레이션) |
| CI role 권한 | IAM role `sw-hub-dev-gha-terraform` 인라인정책 `terraform-dev` | terraform 권한 범위 | 스코프(ec2/rds/s3 + iam은 `sw-hub-*`) |
| `CLOUDFLARE_API_TOKEN` | GH Secret (이 레포) | cloudflare provider | 시크릿 |
| `TF_VAR_CLOUDFLARE_ACCOUNT_ID` | GH Secret | terraform 변수 | 값 |
| `TF_VAR_CLOUDFLARE_ZONE_NAME` | GH Secret | terraform 변수 (예: `yeoun.org`) | 값 |
| `TF_VAR_CLOUDFLARE_HOSTNAME` | GH Secret | terraform 변수 (예: `moa.yeoun.org`) | 값 |
| Terraform state | S3 `sw-hub-dev-tfstate-<account_id>` (암호화·버전관리·락파일) | 인프라 상태(민감값 포함) | — |
| 승인 게이트 | GH Environment `dev-apply` (reviewer 지정, dev 브랜치만) | apply 전 사람 승인 | — |
| 로컬 terraform | `~/.aws` 의 IAM 사용자 프로파일 | 로컬 plan/import/부트스트랩 | 액세스 키(개인) |

> state 백엔드는 `terraform/environments/dev/backend.tf`. 잠금은 S3 네이티브 락파일(`use_lockfile`) — DynamoDB 불필요.

---

## 3. 런타임/앱 인증 (별개 흐름)

앱(BE) 배포와 런타임은 인프라 파이프라인과 분리되어 있다.

```
[MOA-Crew/BE dev 머지] → BE CI(jar) → BE CD(cd.yml)
    │  EC2_SSH_PRIVATE_KEY (BE repo GH Secret)로 SSH
    ▼
[EC2] docker run moa-be
    ├─ RDS 접속    : LOCAL_POSTGRES_* (BE repo GH Secret) → /opt/moa/be/moa-be.env (600 root)
    ├─ S3 접근     : EC2 instance profile(sw-hub-dev-app-role) — 키 없음
    ├─ IMDSv2 강제 : 토큰 없는 메타데이터 접근 차단(SSRF 방어)
    └─ cloudflared : 터널 토큰(계정/터널ID/secret 내장)으로 Cloudflare에 아웃바운드 연결
                     → 외부는 https://moa.yeoun.org (Cloudflare 엣지 TLS)
```

| 경로 | 인증 수단 | 영구 키 |
|---|---|---|
| CI → AWS (인프라) | OIDC 단기 토큰 | ❌ |
| CI → Cloudflare | API 토큰 (GH Secret) | 🔐 |
| 앱배포 CI → EC2 | SSH 키 (GH Secret) | 🔐 |
| EC2 앱 → RDS | DB 비번 (env 파일) | 🔐 |
| EC2 → AWS(S3) | instance profile | ❌ |
| EC2 → Cloudflare | 터널 토큰 | 🔐 |
| 외부 → 앱 | Cloudflare Tunnel(https) | — |

---

## 4. 부트스트랩 (1회성, 수동/관리자)

CI 파이프라인이 돌기 위해 미리 만들어 둔 것들. (재구축 시 참고)

1. **S3 state 버킷**: `sw-hub-dev-tfstate-<account_id>` (버전관리/SSE/퍼블릭 차단) + 로컬 state를 S3로 마이그레이션.
2. **GitHub OIDC provider**: `token.actions.githubusercontent.com`, audience `sts.amazonaws.com`.
3. **CI role** `sw-hub-dev-gha-terraform`:
   - 신뢰정책: 위 OIDC provider, `sub = repo:MOA-Crew/iac:*`, `aud = sts.amazonaws.com`.
   - 권한: 인라인 `terraform-dev` (ec2/rds/s3 + `sw-hub-*` 범위 IAM + PassRole(ec2)).
4. **GitHub Environment** `dev-apply`: required reviewer 지정, 배포 브랜치 `dev`로 제한.
5. **GH Secrets 4개** 등록 (위 표).

> CI role/OIDC provider는 "CI가 인프라를 만들기 위한 권한"이라, 부트스트랩 단계에서 사람이 생성한다(파이프라인 자체가 자기 권한을 만들지 않음).

---

## 5. 드리프트 처리 메모

기존(수동/외부) 인프라를 terraform 관리로 편입하며 적용한 안전장치.

- **Cloudflare 터널** (`cloudflare_zero_trust_tunnel_cloudflared.moa`): import 후 secret을 API로 다시 읽을 수 없어, 매 apply마다 `secret`이 바뀐 것으로 잡혀 터널이 재생성(라이브 끊김)된다. → `lifecycle { ignore_changes = [secret] }`. 의도적 시크릿 회전이 필요하면 이 줄을 풀고 토큰 재발급.
- **RDS** (`aws_db_instance.this`): `auto_minor_version_upgrade`(기본 true)로 마이너 버전이 자동 상승하는데, terraform이 고정 버전으로 되돌리려다 다운그레이드=apply 실패. → `lifecycle { ignore_changes = [engine_version] }`.
- **EC2** (`aws_instance.this`): AMI가 `most_recent`라 새 우분투 AMI 출시 시 인스턴스가 교체된다. 자동 apply가 인스턴스를 날리지 않도록 `lifecycle { ignore_changes = [ami] }`.

---

## 6. 일상 운영

- **인프라 변경**: `terraform/**` 수정 → PR → plan 코멘트 검토 → dev 머지 → `dev-apply` 승인 → apply.
- **로컬에서 plan/import**: `~/.aws` 자격증명 + `CLOUDFLARE_API_TOKEN`/`TF_VAR_cloudflare_*` 환경변수 주입 후 `terraform -chdir=terraform/environments/dev plan`.
- **apply는 항상 승인 게이트를 거친다.** 자동 apply 없음.
