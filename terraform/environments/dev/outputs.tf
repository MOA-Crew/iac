output "network_summary" {
  description = "network 모듈 요약 (VPC id, subnet id 등)"
  value       = module.network.summary
}

output "ec2_summary" {
  description = "ec2 모듈 요약 (public IP, private key 경로 포함)"
  value       = module.ec2.summary
}

output "rds_summary" {
  description = "rds 모듈 요약 (endpoint, db_name 등)"
  value       = module.rds.summary
}

output "s3_buckets" {
  description = "생성된 S3 버킷 (용도 → 버킷 이름)."
  value       = { for k, m in module.s3 : k => m.bucket_id }
}

output "rds_endpoint" {
  description = "RDS 접속 주소. 앱 설정에 이걸로 박음."
  value       = module.rds.endpoint
}

output "rds_password" {
  description = "RDS master 비밀번호. terraform output -raw rds_password 로 조회."
  value       = module.rds.password
  sensitive   = true
}

# 노트북 → (EC2 bastion) → RDS 로 가는 SSH 포트포워딩 명령어.
# 실행하면 노트북의 localhost:15432 가 RDS:5432 로 터널링됨.
output "rds_tunnel_command" {
  description = "노트북에서 RDS 접속용 SSH 터널. 그대로 복붙해서 사용."
  value       = "ssh -i ${module.ec2.private_key_path} -L 15432:${module.rds.address}:${module.rds.port} ubuntu@${module.ec2.public_ips[0]}"
}

output "cloudflare_tunnel_id" {
  description = "Cloudflare Tunnel ID"
  value       = cloudflare_zero_trust_tunnel_cloudflared.moa.id
}

output "cloudflare_hostname" {
  description = "Cloudflare Tunnel로 공개되는 호스트명"
  value       = var.cloudflare_hostname
}

output "cloudflare_tunnel_token" {
  description = "EC2 cloudflared connector에 주입할 tunnel token. terraform output -raw cloudflare_tunnel_token 로 조회."
  value       = cloudflare_zero_trust_tunnel_cloudflared.moa.tunnel_token
  sensitive   = true
}
