# 작업 기록 — prod/dev 분리 & Ansible OIDC 전환 (2026-06)

단일 `sw-hub-dev` 인프라를 **prod/dev 분리 + EC2·RDS `moa` 리네임 + cd-ansible OIDC 전환**으로 옮긴 작업의 기록. 최종 아키텍처는 [architecture.md](./architecture.md), 인증/시크릿은 [cicd-and-auth.md](./cicd-and-auth.md)·[secrets-and-vault-backup.md](./secrets-and-vault-backup.md) 참고.

## 무엇을 했나 (요약)

1. **prod/dev 분리** — 단일 terraform 스택에서 EC2 2대(`moa-prod` t3.small / `moa-dev` t3.micro) + **공유 RDS 1대**(`moa-prod-db`, database `moa_prod`/`moa_dev`) + Cloudflare 터널·DNS 2벌(`for_each`). VPC·IAM·S3·state·CI role은 `sw-hub` 유지.
2. **CI/CD 분리** — `terraform.yml` → `cd-terraform.yml` + `cd-ansible.yml`. `main`/`dev` 브랜치 분리, `dev-apply`/`prod-apply` 승인 게이트.
3. **Cloudflare hostname 빈 값 버그 수정** — 미설정 GH secret이 `""`로 치환돼 빈 hostname으로 apply가 절반-적용(RDS 생성 후 Cloudflare에서 실패). → secret 등록 + `plan` 단계 `validation` 가드(빈 값이면 즉시 실패).
4. **시크릿 채우기(1회 수동)** — apply 후 state에서 터널 토큰·RDS 비번·SSH 키를 떠서 GH 환경/Repo 시크릿에 등록. 값은 출력 없이 `gh secret set`으로 주입.
5. **cd-ansible OIDC 전환** — placeholder 인벤토리(`203.0.113.x`)/환경 시크릿 의존 제거. 배포 잡이 OIDC로 state를 읽어 **인벤토리·SSH키·env를 런타임 생성**. (SSH 키는 첫 실행 race를 피해 state의 `tls_private_key` 리소스에서 읽음.) 런타임 인벤토리를 `inventories/dev/`에 생성해 `group_vars/all` 로드.
6. **시크릿 정리** — cd-ansible가 시크릿 0개가 되면서 죽은 8개 삭제. iac는 Cloudflare 5개만 남음.
7. **BE 시크릿 갱신** — 새 인프라(IP·RDS 엔드포인트·비번·SSH 키)에 맞춰 BE `dev`/`prod` env 갱신. `EC2_HOST`/`EC2_SSH_PRIVATE_KEY`를 repo→환경별로 분리, 구 repo 시크릿 삭제.
8. **Vaultwarden 백업** — infra 시크릿을 개인 vault(`MOA Infra`)에 백업. → [secrets-and-vault-backup.md](./secrets-and-vault-backup.md).

## PR

| PR | 내용 |
|---|---|
| #10 | dev/prod 분리 (공유 인프라 + 앱 박스 2대, EC2/RDS `moa` 네이밍) |
| #11 | `cloudflare_hostname` 빈 값 plan 단계 차단 (validation) |
| #12 | cd-ansible OIDC/state 기반 전환 + EC2 SSH 키 sensitive output |
| #13 | cd-ansible 런타임 인벤토리를 `inventories/dev/`에 생성 (group_vars 로드 fix) |

## 주요 결정 (왜)

- **EC2·RDS만 `moa`로 재생성**: 보존할 데이터가 없어 네이밍 부채를 청산. VPC·IAM·S3·state·CI role은 `sw-hub` 유지 — CI role IAM 권한 스코프가 `sw-hub-*`라 IAM까지 바꾸면 admin/STS 작업 필요(EC2/RDS는 이름 제한 없는 액션이라 `moa`로 생성 가능).
- **RDS 1대 공유**: 비용. 인스턴스는 하나, database(`moa_prod`/`moa_dev`)로만 분리.
- **cd-ansible를 (bw 아닌) state 기반으로**: bw를 CI가 읽게 하려면 **마스터 비번을 CI에 둬야** 하고 그건 개인 vault 전체를 CI에 노출 → 거부. terraform state는 이미 모든 값을 담은 단일 소스 + OIDC로 키 없이 읽힘.
- **SSH 키는 state의 리소스에서 읽음**: 신설한 sensitive output은 첫 `apply` 후에야 state에 생겨, cd-terraform/cd-ansible 동시 트리거 시 race 가능. `tls_private_key` 리소스는 현재 state에 이미 있어 첫 실행부터 안전.

## 현재 상태 / 남은 것

- ✅ 인프라 apply 완료(EC2 2대·공유 RDS·터널 2개·DNS 2개), 시크릿 채움/정리, cd-ansible OIDC 전환, BE 시크릿 갱신, Vaultwarden 백업.
- ⏳ **PR #13 머지** 후 cd-ansible가 `moa-dev` 박스 구성(docker/redis/cloudflared) + `moa_dev` DB 생성.
- ⏳ **BE dev 배포**(BE 레포 `dev` 푸시) → `https://dev-moa.yeoun.org`.
- ⏳ **prod**: `main` 흐름 동일. 단 **prod 첫 부팅**은 빈 `moa_prod` + `ddl-auto=validate`라 앱이 안 뜬다 → `JPA_DDL_AUTO=update`를 prod env에 **1회** 설정해 스키마 생성 후 되돌릴 것.

## 운영 메모

- `apply`는 항상 `dev-apply` 승인 게이트를 거친다(자동 apply 없음). 단일 state라 apply는 `dev` 브랜치에서만 돈다.
- 인프라 변경으로 EC2가 재생성되면 IP·SSH 키가 바뀐다 → BE 시크릿(`EC2_HOST`/`EC2_SSH_PRIVATE_KEY`)과 Vaultwarden 백업을 다시 갱신([vault-backup.sh](../tools/vault-backup.sh)는 멱등).
