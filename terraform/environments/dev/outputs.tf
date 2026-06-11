output "network_summary" {
  description = "network 모듈 요약 (VPC id, subnet id 등). 공유 네트워크(sw-hub)."
  value       = module.network.summary
}

output "ec2_prod_summary" {
  description = "prod 박스(moa-prod) 요약."
  value       = module.ec2_prod.summary
}

output "ec2_dev_summary" {
  description = "dev 박스(moa-dev) 요약."
  value       = module.ec2_dev.summary
}

output "ec2_prod_public_ip" {
  description = "prod 박스 public IP."
  value       = module.ec2_prod.public_ips[0]
}

output "ec2_dev_public_ip" {
  description = "dev 박스 public IP."
  value       = module.ec2_dev.public_ips[0]
}

output "ec2_prod_private_key_path" {
  description = "prod 박스 SSH key 로컬 경로."
  value       = module.ec2_prod.private_key_path
}

output "ec2_dev_private_key_path" {
  description = "dev 박스 SSH key 로컬 경로."
  value       = module.ec2_dev.private_key_path
}

output "rds_summary" {
  description = "공유 RDS(moa-db) 요약."
  value       = module.rds.summary
}

output "rds_endpoint" {
  description = "공유 RDS 접속 주소. prod=moa_prod, dev=moa_dev database 사용."
  value       = module.rds.endpoint
}

output "rds_password" {
  description = "RDS master 비밀번호. terraform output -raw rds_password 로 조회."
  value       = module.rds.password
  sensitive   = true
}

output "s3_buckets" {
  description = "생성된 S3 버킷 (용도 → 버킷 이름). 공유, sw-hub 네이밍 유지."
  value       = { for k, m in module.s3 : k => m.bucket_id }
}

# 노트북 → (prod 박스 bastion) → RDS 로 가는 SSH 포트포워딩 명령어.
output "rds_tunnel_command" {
  description = "노트북에서 RDS 접속용 SSH 터널(prod 박스 경유). 그대로 복붙."
  value       = "ssh -i ${module.ec2_prod.private_key_path} -L 15432:${module.rds.address}:${module.rds.port} ubuntu@${module.ec2_prod.public_ips[0]}"
}

output "cloudflare_hostnames" {
  description = "환경별 공개 호스트명."
  value = {
    prod = var.cloudflare_hostname_prod
    dev  = var.cloudflare_hostname_dev
  }
}

output "cloudflare_tunnel_ids" {
  description = "환경별 Cloudflare Tunnel ID."
  value       = { for k, t in cloudflare_zero_trust_tunnel_cloudflared.this : k => t.id }
}

output "cloudflare_tunnel_tokens" {
  description = "환경별 터널 토큰. 각 박스 cloudflared 에 주입. terraform output -json cloudflare_tunnel_tokens 로 조회."
  value       = { for k, t in cloudflare_zero_trust_tunnel_cloudflared.this : k => t.tunnel_token }
  sensitive   = true
}
