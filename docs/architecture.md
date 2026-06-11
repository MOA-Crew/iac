# MOA Infrastructure — Architecture (prod + dev)

실제 구성. 인프라는 Terraform으로 프로비저닝하고, 서버 런타임은 Ansible로 구성한다. **공유 인프라(VPC·RDS 인스턴스·S3·IAM) 위에 앱 박스 2대**(prod/dev)를 올린 모델 — 비싼 stateful 자원은 공유하고 환경은 박스·database·터널·도메인으로 나눈다.

## 설계 원칙

- **앱 포트를 인터넷에 직접 열지 않는다.** 외부 진입은 Cloudflare Tunnel(아웃바운드 연결)로만 받는다.
- **DB는 비공개.** RDS는 private subnet에 두고 두 박스(prod/dev) 보안그룹에서만 접근을 허용한다.
- **영구 자격증명 최소화.** CI→AWS는 OIDC, EC2→S3는 instance profile로 키를 두지 않는다.
- **비용 우선.** RDS는 인스턴스 1개를 prod/dev가 database로 나눠 공유. dev 박스는 t3.micro. Redis는 ElastiCache 대신 박스 내부 컨테이너, 단일 AZ, 백업 최소.

## 전체 그림

```text
        인터넷
          │  moa.yeoun.org              dev-moa.yeoun.org
          ▼                                    ▼
   ┌────────────┐  터널 moa-prod      ┌────────────┐  터널 moa-dev
   │ Cloudflare │                     │ Cloudflare │
   └─────┬──────┘                     └─────┬──────┘
         │  아웃바운드 터널만 (인바운드 개방 없음)  │
 ┌───────┼──────────────────────────────────┼───────────────────┐
 │ VPC sw-hub-dev-vpc 10.10.0.0/16          │                   │
 │   public subnet ×2 (10.10.1.0/24, 10.10.2.0/24)              │
 │   ┌────────────────────────┐   ┌────────────────────────┐    │
 │   │ moa-prod  (t3.small)   │   │ moa-dev  (t3.micro)    │    │
 │   │  ├ moa-be :8080        │   │  ├ moa-be :8080        │    │
 │   │  ├ cloudflared→moa-prod│   │  ├ cloudflared→moa-dev │    │
 │   │  └ redis 127.0.0.1     │   │  └ redis 127.0.0.1     │    │
 │   └───────────┬────────────┘   └───────────┬────────────┘    │
 │               │  5432: 두 박스 SG에서만 허용  │                 │
 │   private subnet ×2 (10.10.11.0/24, 10.10.12.0/24)           │
 │   ┌──────────────────────────────────────────────────────┐  │
 │   │ RDS PostgreSQL  moa-prod-db (공유, 비공개, gp3 암호화)   │  │
 │   │   ├ database moa_prod (prod)                          │  │
 │   │   └ database moa_dev  (dev, +pgvector)                │  │
 │   └──────────────────────────────────────────────────────┘  │
 └──────────────────────────────────────────────────────────────┘
       두 박스 → S3 (sw-hub) : instance profile (키 없음)
```

## 컴포넌트

### 네트워크 (`terraform/modules/network`)
- VPC `10.10.0.0/16`, DNS 지원/호스트네임 on.
- public subnet ×2 (`map_public_ip_on_launch=true`), private subnet ×2 — RDS subnet group이 ≥2 AZ를 요구해 최소 2개.
- IGW + public route table(`0.0.0.0/0 → IGW`). private route table은 **외부 outbound 없음(NAT 미사용)** — 필요해지면 NAT route 추가.

### 컴퓨트 (`terraform/modules/ec2`, 2회 호출 → `module.ec2_prod`/`module.ec2_dev`)
- Ubuntu 22.04 LTS amd64(`most_recent`). **`moa-prod`(t3.small)** + **`moa-dev`(t3.micro)**, 같은 VPC public subnet.
- 호출마다 ED25519 SSH 키페어 따로 생성 → `moa-prod.pem`/`moa-dev.pem`(0600). private key는 tfstate에도 저장되므로 state 보호 필수.
- SG: SSH(22)만 인바운드 허용(박스마다 별도 SG), **앱 포트는 비공개** — 외부 노출은 Cloudflare Tunnel 경유.
- **IMDSv2 강제**(`http_tokens=required`, hop_limit=1): SSRF로 인한 IAM 임시자격증명 탈취 차단.
- 공유 IAM instance profile(`sw-hub-dev-app-profile`)로 S3 접근(액세스 키 없음).

### 데이터베이스 (`terraform/modules/rds`, 인스턴스 1개 공유)
- PostgreSQL `moa-prod-db`, private subnet group(≥2 AZ), `publicly_accessible=false`, `multi_az=false`.
- database 2개: `moa_prod`(RDS 초기 생성, prod), `moa_dev`(Ansible `postgres` role 생성, dev). 각각 pgvector.
- SG 인바운드는 **두 박스 SG에서만** DB 포트 허용(`app_security_group_ids` 리스트).
- master 비밀번호 `random_password` 자동 생성(tfstate sensitive), gp3 + 암호화.
- 편의: 백업 0일·최종 스냅샷 생략·삭제보호 해제 (운영 강화 시 반대로).

### 스토리지 (`terraform/modules/s3`)
- 앱 버킷(`sw-hub-dev-*`). 두 박스 모두 instance profile로 접근.

### 엣지 / 인그레스 (`terraform/environments/dev/cloudflare.tf`, `for_each`)
- 환경별 Zero Trust Tunnel + ingress config(`hostname → http://localhost:8080`, 그 외 404) + DNS CNAME(proxied) 2벌을 Terraform이 관리.
- 각 박스의 `cloudflared` 컨테이너가 자기 터널 토큰으로 아웃바운드 연결 → 외부는 `https://moa.yeoun.org`(prod)·`https://dev-moa.yeoun.org`(dev).

## 서버 런타임 (Ansible)

`terraform apply` 가 만든 두 박스 위에 런타임을 구성한다. 인벤토리는 `prod_app`/`dev_app` 그룹으로 나뉘고, role(`common`, `ram_optimization`(zram), `docker`, `redis`, `cloudflared`, `postgres`)은 그룹 vars(database·hostname·키)만 달리해 공용으로 돈다.

## 배포 / 인증

- 인프라 변경: Terraform **GitOps**(단일 스택, PR→plan, `dev` 머지→`dev-apply` 승인→apply). CI는 GitHub OIDC.
- 서버 구성: Ansible CD가 브랜치로 박스 선택(`dev`→dev_app/`dev-apply`, `main`→prod_app/`prod-apply`).
- 앱 배포(BE)는 별개 흐름(BE 레포 CD → 각 박스 docker run, prod=moa_prod·dev=moa_dev).
- 전체 자격증명 흐름은 [cicd-and-auth.md](./cicd-and-auth.md) 참고.

## 네이밍

브랜드는 **MOA**. EC2·RDS·Cloudflare 터널은 `moa-*`, VPC·IAM·S3·state·CI role은 `sw-hub-*` 유지(혼재는 의도). 자세한 내용은 루트 [README](../README.md)의 네이밍 노트.
