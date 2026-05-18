# Terraform output → Ansible inventory/vars 자동 동기화.
# apply 마다 아래 파일들이 재생성됨.
# destroy 시엔 같이 삭제됨.

locals {
  ansible_inventory_dir = "${path.module}/../../../ansible/inventories/dev"
}

# 호스트 정의 + 비밀 아닌 변수 (EC2 IP, SSH key 경로, RDS 접속 메타데이터).
resource "local_file" "ansible_hosts" {
  filename        = "${local.ansible_inventory_dir}/hosts.yml"
  file_permission = "0644"
  content = templatefile("${path.module}/templates/hosts.tmpl.yml", {
    app_hosts        = module.ec2.public_ips
    private_key_path = module.ec2.ansible_private_key_path
    rds_host         = module.rds.address
    rds_port         = module.rds.port
    rds_database     = module.rds.db_name
    rds_user         = module.rds.username
  })
}

# 민감 정보 (RDS master 비밀번호). gitignore 대상.
resource "local_sensitive_file" "ansible_secrets" {
  filename        = "${local.ansible_inventory_dir}/group_vars/all/secrets.yml"
  file_permission = "0600"
  content = yamlencode({
    postgres_rds_password = module.rds.password
  })
}
