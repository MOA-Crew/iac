output "instance_ids" {
  value = aws_instance.this[*].id
}

output "public_ips" {
  description = "각 인스턴스의 public IP. SSH 접속 시 사용."
  value       = aws_instance.this[*].public_ip
}

output "security_group_id" {
  description = "다른 모듈(예: RDS)이 이 EC2를 source로 허용할 때 참조."
  value       = aws_security_group.this.id
}

output "private_key_path" {
  description = "자동 생성된 private key가 떨궈진 로컬 경로 (절대경로). ssh -i <이 경로> ubuntu@<public_ip>"
  value       = abspath(local_sensitive_file.private_key.filename)
}

output "summary" {
  value = {
    name_prefix      = local.name_prefix
    instance_count   = var.instance_count
    instance_type    = var.instance_type
    ami_id           = data.aws_ami.ubuntu.id
    public_ips       = aws_instance.this[*].public_ip
    private_key_path = abspath(local_sensitive_file.private_key.filename)
  }
}
