# 시크릿 관리 & Vaultwarden 백업

MOA 인프라의 시크릿이 (1) **어디에 있고 무엇이 OIDC로 대체됐는지**, (2) **terraform state에서 어떻게 꺼내는지**, (3) **개인 Vaultwarden 백업**을 정리한다.

## 1. 원칙 — terraform state가 단일 소스(single source of truth)

terraform이 만든 모든 인프라 비밀(RDS 비밀번호·SSH 키·Cloudflare 터널 토큰)은 **S3 원격 state**(`sw-hub-dev-tfstate-<account>/dev/terraform.tfstate`, 암호화·버전관리)에 들어 있다. GitHub 시크릿에는 "state로 못 가져오는 것"만 둔다.

- CI(`cd-terraform`·`cd-ansible`)는 **GitHub OIDC**로 AWS를 assume해 state를 직접 읽는다 → **저장된 AWS 키 0개.**
- `cd-ansible`는 시크릿을 **하나도 안 쓴다** — IP·SSH키·터널토큰·RDS 접속정보를 전부 state에서 런타임에 읽어 인벤토리·env를 만든다.

## 2. GitHub 시크릿 인벤토리 (현재)

### iac 레포 (`MOA-Crew/iac`)

| 시크릿 | 스코프 | 쓰는 곳 | OIDC로 제거 가능? |
|---|---|---|---|
| `CLOUDFLARE_API_TOKEN` | repo | cd-terraform (cloudflare provider 인증) | ❌ 본질적 비밀 |
| `TF_VAR_CLOUDFLARE_ACCOUNT_ID` | repo | cd-terraform 입력값 | ❌ (만들 대상 정의 → state에 없음) |
| `TF_VAR_CLOUDFLARE_ZONE_NAME` | repo | cd-terraform 입력값 | ❌ |
| `TF_VAR_CLOUDFLARE_HOSTNAME_PROD` / `_DEV` | repo | cd-terraform 입력값 | ❌ |
| `dev-apply` / `prod-apply` (env) | — | **시크릿 없음** — 승인 게이트로만 | — |

> **AWS는 OIDC-only**(저장 키 0). Cloudflare 5개만 남고, 그 중 진짜 비밀은 `CLOUDFLARE_API_TOKEN` 하나다(나머지 4개는 account_id·도메인이라 공개값이지만, "도메인을 코드에 커밋하지 않는다"는 방침상 시크릿으로 유지).
>
> `cd-ansible`가 OIDC/state 기반으로 바뀌면서 옛 환경 시크릿(`ANSIBLE_SSH_PRIVATE_KEY`·`CLOUDFLARED_TUNNEL_TOKEN`·`TF_VAR_CLOUDFLARE_HOSTNAME`)과 repo `POSTGRES_RDS_PASSWORD`는 **삭제됐다.**

### BE 레포 (`MOA-Crew/BE`) — 별개 흐름

앱 배포(`cd.yml`)가 박스에 SSH로 붙어 컨테이너를 띄운다. OIDC/state로 대체 불가(JWT·메일 비번은 애초에 state에 없음). 박스가 둘이라 `dev`/`prod` Environment에 박스별 값을 둔다.

| 시크릿 | 스코프 | 비고 |
|---|---|---|
| `EC2_HOST` / `EC2_SSH_PRIVATE_KEY` | dev·prod env | 박스별 IP·SSH 키 (dev=moa-dev, prod=moa-prod) |
| `POSTGRES_URL` | dev·prod env | jdbc URL (`…:5432/moa_dev` / `…/moa_prod`) |
| `POSTGRES_USERNAME` / `POSTGRES_PASSWORD` | repo | 공유 RDS master (`moa_admin`) |
| `EC2_USER` | repo | `ubuntu` |
| `JWT_SECRET` | dev·prod env | 앱 JWT 서명 키 |
| `GMAIL_USERNAME` / `GMAIL_APP_PASSWORD` | repo | 메일 발송 |
| `APP_PORT` | dev·prod env | 8080 |

## 3. state에서 시크릿 꺼내기

**로컬** (state 버킷 접근 권한 있는 AWS 자격증명 필요):

```bash
cd terraform/environments/dev
terraform output -raw  rds_password               # RDS master 비밀번호
terraform output -json cloudflare_tunnel_tokens   # {"prod":"…","dev":"…"}
terraform output -raw  ec2_prod_private_key       # moa-prod SSH key (OpenSSH)
terraform output -raw  ec2_dev_private_key        # moa-dev  SSH key
terraform output -raw  rds_endpoint               # host:port
```

**terraform 없이** (state JSON 직접):

```bash
aws s3 cp s3://sw-hub-dev-tfstate-850919911012/dev/terraform.tfstate - \
  | jq -r '.outputs.rds_endpoint.value'
```

## 4. Vaultwarden 개인 백업

state는 S3에 안전하게 있지만, **사람이 손으로 꺼내쓸 백업**으로 개인 Vaultwarden(`vault.yeoun.org`)에도 둔다.

- **위치**: `MOA Infra` 폴더, 5개 항목
  | 항목 | 타입 | 내용 |
  |---|---|---|
  | `MOA · RDS (moa-db, shared)` | login | user `moa_admin` / 비번 / host·DB(moa_prod·moa_dev) |
  | `MOA · EC2 moa-prod SSH` | secure note | private key + host(3.39.252.60)·user |
  | `MOA · EC2 moa-dev SSH` | secure note | private key + host(43.203.227.207)·user |
  | `MOA · CF tunnel token (prod)` | secure note | 터널 토큰 (hidden) |
  | `MOA · CF tunnel token (dev)` | secure note | 터널 토큰 (hidden) |
- **방법**: [`tools/vault-backup.sh`](../tools/vault-backup.sh) — state에서 값을 읽어 `bw`로 **멱등 upsert**. 비밀값은 스크립트·채팅·디스크에 안 남는다(마스터 비번은 `bw unlock` 프롬프트로만 입력).
- **실행**:
  ```bash
  # 사전: AWS 자격증명 + bw apikey 로그인 (스크립트 헤더 참고)
  bash tools/vault-backup.sh      # → 마스터 비번 입력 → 5개 생성/갱신
  ```
- 값이 바뀌면(예: EC2 재생성) 다시 돌리면 된다(멱등).

### ⚠️ 이 백업에 **포함되지 않는** 시크릿

state에 없는 값은 vault 백업에도 없다 — **별도 보관 필요**:

- iac `CLOUDFLARE_API_TOKEN`
- BE `JWT_SECRET`, `GMAIL_USERNAME` / `GMAIL_APP_PASSWORD`

> GitHub 시크릿은 **write-only**(등록 후 다시 못 읽음)다. 위 값들은 다른 사본이 없으면 복구 불가하니, 발급/생성 시점에 따로 보관할 것.

## 5. 보안 메모

- 마스터 비밀번호·API 토큰·SSH 키·DB 비번을 **코드/커밋/채팅에 남기지 않는다.**
- Vaultwarden API 키(client_id/secret)가 노출된 적 있으면 **회전**(Vaultwarden → Account Settings → API Key).
- state 자체가 민감값을 평문 보관하므로 **state 버킷 접근 권한을 엄격히** 관리한다(SSE·버전관리·퍼블릭 차단 적용).
