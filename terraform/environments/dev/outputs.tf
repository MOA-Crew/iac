output "network_summary" {
  description = "network 모듈 요약 (VPC id, subnet id 등)"
  value       = module.network.summary
}

output "ec2_summary" {
  description = "ec2 모듈 골조 요약"
  value       = module.ec2.summary
}

output "rds_summary" {
  description = "rds 모듈 골조 요약"
  value       = module.rds.summary
}
