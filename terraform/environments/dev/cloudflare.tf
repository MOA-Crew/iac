# Cloudflare DNS + Tunnel routing for MOA dev.
#
# 인증 토큰은 코드/vars에 박지 않는다.
# 로컬/CI에서 CLOUDFLARE_API_TOKEN 환경변수로 주입한다.

data "cloudflare_zone" "moa" {
  name = var.cloudflare_zone_name
}

resource "random_id" "cloudflare_tunnel_secret" {
  byte_length = 32
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "moa" {
  account_id = var.cloudflare_account_id
  name       = var.cloudflare_tunnel_name
  secret     = coalesce(var.cloudflare_tunnel_secret, random_id.cloudflare_tunnel_secret.b64_std)

  lifecycle {
    # 기존 터널을 import한 경우, secret은 cloudflare API로 다시 읽을 수 없어 state에 비어 있다.
    # 이를 무시하지 않으면 매 apply마다 secret 변경=터널 재생성으로 잡혀 라이브 터널(cloudflared 토큰)이 끊긴다.
    # 따라서 secret 변경은 무시한다. (의도적 시크릿 회전이 필요하면 이 줄을 풀고 토큰을 재발급한다.)
    ignore_changes = [secret]
  }
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "moa" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.moa.id

  config {
    ingress_rule {
      hostname = var.cloudflare_hostname
      service  = var.cloudflare_origin_service
    }

    ingress_rule {
      service = "http_status:404"
    }
  }
}

resource "cloudflare_record" "moa_hostname" {
  zone_id = data.cloudflare_zone.moa.id
  name    = trimsuffix(var.cloudflare_hostname, ".${var.cloudflare_zone_name}")
  type    = "CNAME"
  value   = cloudflare_zero_trust_tunnel_cloudflared.moa.cname
  proxied = true
  ttl     = 1
}
