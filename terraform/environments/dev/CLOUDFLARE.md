# Cloudflare Terraform 운영 메모

MOA의 public hostname과 Cloudflare Tunnel은 Terraform에서 관리한다.
환경별로 터널·ingress·DNS 레코드를 `for_each`(`cloudflare_edges` = {prod, dev})로 2벌 만든다.
리소스 주소는 `cloudflare_zero_trust_tunnel_cloudflared.this["prod"]` / `["dev"]` 형태.

## 인증/변수 주입

Cloudflare API token은 코드에 하드코딩하지 않는다.

```bash
export CLOUDFLARE_API_TOKEN=...
```

도메인명/호스트명도 Terraform 변수 기본값에 박지 않고 환경변수로 주입한다.

```bash
export TF_VAR_cloudflare_account_id=...
export TF_VAR_cloudflare_zone_name=...
export TF_VAR_cloudflare_hostname_prod=...   # moa.yeoun.org
export TF_VAR_cloudflare_hostname_dev=...    # dev-moa.yeoun.org
```

터널 이름은 `app_project_name`("moa")으로 자동 생성된다(`moa-prod`/`moa-dev`). origin은 필요 시:

```bash
export TF_VAR_cloudflare_origin_service=...
```

`terraform.tfvars`를 쓰는 경우에도 실제 도메인 값은 커밋하지 말고 환경별 로컬/CI secret 파일로 분리한다.

## 새로 만드는 경우

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
terraform output -json cloudflare_tunnel_tokens   # { "prod": "...", "dev": "..." }
```

출력된 환경별 tunnel token을 해당 박스 Ansible(`cloudflared_tunnel_token`)·GH Environment 시크릿으로 주입한다. 토큰 값은 커밋하지 않는다.

Ansible 쪽 runtime hostname도 환경변수 또는 extra-var로 주입한다.

```bash
export MOA_PUBLIC_HOSTNAME=...
export CLOUDFLARED_TUNNEL_TOKEN=...
ansible-playbook ansible/playbooks/site.yml --tags cloudflared
```

또는:

```bash
ansible-playbook ansible/playbooks/site.yml \
  --tags cloudflared \
  -e "cloudflared_hostname=$MOA_PUBLIC_HOSTNAME cloudflared_tunnel_token=$CLOUDFLARED_TUNNEL_TOKEN"
```

## 이미 Cloudflare에서 만든 리소스를 Terraform으로 가져오는 경우

`for_each` 라 주소에 키가 붙는다. 필요 시 환경별로 import:

```bash
terraform import 'cloudflare_zero_trust_tunnel_cloudflared.this["prod"]' <account_id>/<tunnel_id>
terraform import 'cloudflare_record.this["prod"]' <zone_id>/<dns_record_id>
```

그 다음 `terraform plan`으로 drift를 확인한다.

## 교체가 쉬운 지점

- 도메인 교체: `TF_VAR_cloudflare_zone_name`, `TF_VAR_cloudflare_hostname_prod` / `_dev`
- Tunnel 이름: `app_project_name`(현재 `moa`) → `moa-prod`/`moa-dev` 자동
- origin 교체: `TF_VAR_cloudflare_origin_service`
- 계정 교체: `TF_VAR_cloudflare_account_id`
- API token 교체: `CLOUDFLARE_API_TOKEN`
- Ansible hostname 교체: `MOA_PUBLIC_HOSTNAME` 또는 `cloudflared_hostname`
