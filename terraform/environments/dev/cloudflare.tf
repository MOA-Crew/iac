# Cloudflare DNS + Tunnel routing for MOA (prod + dev).
#
# 인증 토큰은 코드/vars에 박지 않는다.
# 로컬/CI에서 CLOUDFLARE_API_TOKEN 환경변수로 주입한다.
#
# 환경별로 터널 1개 + ingress config + DNS 레코드를 만든다.
#   prod → moa.yeoun.org      → prod 박스(cloudflared connector)
#   dev  → dev-moa.yeoun.org  → dev 박스
# 각 박스가 자기 터널 토큰으로 아웃바운드 연결하므로 터널은 박스(=환경)마다 따로 둔다.

locals {
  cloudflare_edges = {
    prod = {
      hostname    = var.cloudflare_hostname_prod
      tunnel_name = "${var.app_project_name}-prod"
    }
    dev = {
      hostname    = var.cloudflare_hostname_dev
      tunnel_name = "${var.app_project_name}-dev"
    }
  }
}

data "cloudflare_zone" "moa" {
  name = var.cloudflare_zone_name
}

resource "random_id" "cloudflare_tunnel_secret" {
  for_each = local.cloudflare_edges

  byte_length = 32
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "this" {
  for_each = local.cloudflare_edges

  account_id = var.cloudflare_account_id
  name       = each.value.tunnel_name
  secret     = random_id.cloudflare_tunnel_secret[each.key].b64_std

  lifecycle {
    # 터널 secret은 cloudflare API로 다시 읽을 수 없어 매 apply마다 변경으로 잡힐 수 있다.
    # 이를 무시하지 않으면 라이브 터널(cloudflared 토큰)이 재생성되어 끊긴다.
    # 의도적 시크릿 회전이 필요하면 이 줄을 풀고 토큰을 재발급한다.
    ignore_changes = [secret]
  }
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "this" {
  for_each = local.cloudflare_edges

  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this[each.key].id

  config {
    ingress_rule {
      hostname = each.value.hostname
      service  = var.cloudflare_origin_service
    }

    ingress_rule {
      service = "http_status:404"
    }
  }
}

resource "cloudflare_record" "this" {
  for_each = local.cloudflare_edges

  zone_id = data.cloudflare_zone.moa.id
  name    = trimsuffix(each.value.hostname, ".${var.cloudflare_zone_name}")
  type    = "CNAME"
  value   = cloudflare_zero_trust_tunnel_cloudflared.this[each.key].cname
  proxied = true
  ttl     = 1
}
