# MOA Infrastructure — Architecture (dev)

현재 dev 환경의 실제 구성. 인프라는 Terraform으로 프로비저닝하고, 서버 런타임은 Ansible로 구성한다.

## 설계 원칙

- **앱 포트를 인터넷에 직접 열지 않는다.** 외부 진입은 Cloudflare Tunnel(아웃바운드 연결)로만 받는다.
- **DB는 비공개.** RDS는 private subnet에 두고 EC2 보안그룹에서만 접근을 허용한다.
- **영구 자격증명 최소화.** CI→AWS는 OIDC, EC2→S3는 instance profile로 키를 두지 않는다.
- **비용 우선 (dev).** Redis는 ElastiCache 대신 EC2 내부 컨테이너, 단일 AZ, 백업 최소.

## 전체 그림

```text
                       인터넷
                         │  https://moa.yeoun.org
                         ▼
                ┌──────────────────┐
                │   Cloudflare     │  엣지 TLS + Zero Trust Tunnel
                └────────┬─────────┘
                         │  아웃바운드 터널만 (인바운드 개방 없음)
 ┌───────────────────────┼────────────────────────────────────┐
 │ VPC 10.10.0.0/16                                            │
 │                                                            │
 │   public subnet ×2 (10.10.1.0/24, 10.10.2.0/24)            │
 │   ┌────────────────────────────────────────────────────┐  │
 │   │  EC2  t3.small / Ubuntu 22.04 / IMDSv2 강제          │  │
 │   │   ├─ moa-be        (Docker, :8080)                   │  │
 │   │   ├─ cloudflared   (Docker) ── 터널 connector ───────┼──┘
 │   │   └─ redis         (Docker, 127.0.0.1:6379)          │
 │   │   instance profile → S3 (키 없음)                     │
 │   └───────────────────────┬────────────────────────────┘  │
 │                           │  5432: EC2 SG에서만 허용         │
 │   private subnet ×2 (10.10.11.0/24, 10.10.12.0/24)         │
 │   ┌────────────────────────────────────────────────────┐  │
 │   │  RDS PostgreSQL  비공개 / gp3 암호화 / pgvector       │  │
 │   └────────────────────────────────────────────────────┘  │
 └────────────────────────────────────────────────────────────┘
```

## 컴포넌트

### 네트워크 (`terraform/modules/network`)
- VPC `10.10.0.0/16`, DNS 지원/호스트네임 on.
- public subnet ×2 (`map_public_ip_on_launch=true`), private subnet ×2 — RDS subnet group이 ≥2 AZ를 요구해 최소 2개.
- IGW + public route table(`0.0.0.0/0 → IGW`). private route table은 **외부 outbound 없음(NAT 미사용)** — 필요해지면 NAT route 추가.

### 컴퓨트 (`terraform/modules/ec2`)
- Ubuntu 22.04 LTS amd64(`most_recent`), `t3.small` 1대, public subnet 배치(공인 IP).
- ED25519 SSH 키페어 Terraform 자동 생성 → 로컬 파일(0600)로 출력. (private key는 tfstate에도 저장되므로 state 보호 필수.)
- SG: SSH(22)만 인바운드 허용, **앱 포트는 비공개** — 외부 노출은 Cloudflare Tunnel 경유.
- **IMDSv2 강제**(`http_tokens=required`, hop_limit=1): SSRF로 인한 IAM 임시자격증명 탈취 차단.
- IAM instance profile로 S3 접근(액세스 키 없음).

### 데이터베이스 (`terraform/modules/rds`)
- PostgreSQL, private subnet group(≥2 AZ), `publicly_accessible=false`, `multi_az=false`(dev).
- SG 인바운드는 **EC2 SG에서만** DB 포트 허용.
- master 비밀번호 `random_password` 자동 생성(tfstate sensitive), gp3 + 암호화.
- dev 편의: 백업 0일·최종 스냅샷 생략·삭제보호 해제 (운영에선 반대로).
- pgvector 확장은 Ansible `postgres` role이 설치.

### 스토리지 (`terraform/modules/s3`)
- dev용 버킷. EC2는 instance profile로 접근.

### 엣지 / 인그레스 (`terraform/environments/dev/cloudflare.tf`)
- Zero Trust Tunnel + ingress config(`hostname → http://localhost:8080`, 그 외 404) + DNS CNAME(proxied)를 Terraform이 관리.
- EC2의 `cloudflared` 컨테이너가 터널 토큰으로 아웃바운드 연결 → 외부는 `https://moa.yeoun.org` 로만 접근.

## 서버 런타임 (Ansible)

`terraform apply` 가 만든 서버 위에 런타임을 구성한다. role: `common`, `ram_optimization`(zram), `docker`, `redis`, `cloudflared`, `postgres`(pgvector).

## 배포 / 인증

- 인프라 변경: Terraform **GitOps**(PR→plan, dev 머지→승인→apply). CI는 GitHub OIDC로 AWS 인증.
- 앱 배포(BE)는 별개 흐름(BE 레포 CD → EC2 docker run).
- 전체 자격증명 흐름은 [cicd-and-auth.md](./cicd-and-auth.md) 참고.

## 네이밍

브랜드는 **MOA**. 일부 AWS 리소스는 초기 SW중심대학 계정 셋업의 `sw-hub`/`swhub` prefix를 유지한다(개명 시 재생성 필요). 자세한 내용은 루트 [README](../README.md)의 네이밍 노트.
