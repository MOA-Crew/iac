# Cloudflare Terraform 운영 메모

MOA dev의 public hostname과 Cloudflare Tunnel은 Terraform에서 관리한다.

## 인증/변수 주입

Cloudflare API token은 코드에 하드코딩하지 않는다.

```bash
export CLOUDFLARE_API_TOKEN=...
```

환경별로 바뀌는 값은 `terraform.tfvars` 또는 CI 변수로 주입한다.

```hcl
cloudflare_account_id     = "..."
cloudflare_zone_name      = "yeoun.org"
cloudflare_hostname       = "moa.yeoun.org"
cloudflare_tunnel_name    = "moa-dev"
cloudflare_origin_service = "http://localhost:8080"
```

## 새로 만드는 경우

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
terraform output -raw cloudflare_tunnel_token
```

출력된 tunnel token은 Ansible의 `cloudflared_tunnel_token`으로 주입한다. 토큰 값은 커밋하지 않는다.

## 이미 Cloudflare에서 만든 리소스를 Terraform으로 가져오는 경우

기존 리소스를 새로 만들지 않으려면 먼저 import한다.

```bash
terraform import cloudflare_zero_trust_tunnel_cloudflared.moa <account_id>/<tunnel_id>
terraform import cloudflare_record.moa_hostname <zone_id>/<dns_record_id>
```

그 다음 `terraform plan`으로 drift를 확인한다.

## 교체가 쉬운 지점

- 도메인 교체: `cloudflare_zone_name`, `cloudflare_hostname`
- Tunnel 이름 교체: `cloudflare_tunnel_name`
- origin 교체: `cloudflare_origin_service`
- 계정 교체: `cloudflare_account_id`
- API token 교체: `CLOUDFLARE_API_TOKEN`
