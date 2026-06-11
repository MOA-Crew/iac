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

output "private_key" {
  description = "생성된 SSH private key (OpenSSH 포맷). state·output 모두 sensitive — `terraform output -raw`로 직접 조회용."
  value       = tls_private_key.this.private_key_openssh
  sensitive   = true
}

# Ansible inventory 에 박을 키 경로.
# - 상대경로 입력이면 inventory_dir 기준 Jinja 표현으로 변환 → 어디서 ansible 명령을 실행해도 안 깨짐.
# - 절대경로(~ 포함) 입력이면 그대로 절대경로 사용.
output "ansible_private_key_path" {
  description = "Ansible inventory에 들어갈 키 경로 표현. 상대경로면 {{ inventory_dir }} 기준."
  value       = local._key_path_is_absolute ? abspath(local_sensitive_file.private_key.filename) : "{{ inventory_dir }}/../../../${var.private_key_output_path}"
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
