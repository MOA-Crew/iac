# Cloudflare Terraform 운영 메모

MOA dev의 public hostname과 Cloudflare Tunnel은 Terraform에서 관리한다.

## 인증/변수 주입

Cloudflare API token은 코드에 하드코딩하지 않는다.

```bash
export CLOUDFLARE_API_TOKEN=...
```

도메인명/호스트명도 Terraform 변수 기본값에 박지 않고 환경변수로 주입한다.

```bash
export TF_VAR_cloudflare_account_id=...
export TF_VAR_cloudflare_zone_name=...
export TF_VAR_cloudflare_hostname=...
```

나머지 환경별 값도 필요하면 같은 방식으로 바꿔 끼운다.

```bash
export TF_VAR_cloudflare_tunnel_name=...
export TF_VAR_cloudflare_origin_service=...
```

`terraform.tfvars`를 쓰는 경우에도 실제 도메인 값은 커밋하지 말고 환경별 로컬/CI secret 파일로 분리한다.

## 새로 만드는 경우

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
terraform output -raw cloudflare_tunnel_token
```

출력된 tunnel token은 Ansible의 `cloudflared_tunnel_token`으로 주입한다. 토큰 값은 커밋하지 않는다.

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

기존 리소스를 새로 만들지 않으려면 먼저 import한다.

```bash
terraform import cloudflare_zero_trust_tunnel_cloudflared.moa <account_id>/<tunnel_id>
terraform import cloudflare_record.moa_hostname <zone_id>/<dns_record_id>
```

그 다음 `terraform plan`으로 drift를 확인한다.

## 교체가 쉬운 지점

- 도메인 교체: `TF_VAR_cloudflare_zone_name`, `TF_VAR_cloudflare_hostname`
- Tunnel 이름 교체: `TF_VAR_cloudflare_tunnel_name`
- origin 교체: `TF_VAR_cloudflare_origin_service`
- 계정 교체: `TF_VAR_cloudflare_account_id`
- API token 교체: `CLOUDFLARE_API_TOKEN`
- Ansible hostname 교체: `MOA_PUBLIC_HOSTNAME` 또는 `cloudflared_hostname`
