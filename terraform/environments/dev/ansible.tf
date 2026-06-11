# Terraform output → Ansible inventory/vars 자동 동기화.
# apply 마다 아래 파일들이 재생성됨.
# destroy 시엔 같이 삭제됨.

locals {
  ansible_inventory_dir = "${path.module}/../../../ansible/inventories/dev"
}

# 호스트 정의 + 비밀 아닌 변수. prod/dev 두 박스를 그룹으로 구분.
# 두 박스는 SSH 키가 달라(모듈별 생성) 그룹 vars로 키 경로를 따로 둔다.
# database 도 그룹별(moa_prod / moa_dev). 비밀(터널 토큰 등)은 CI -e/시크릿으로 주입.
resource "local_file" "ansible_hosts" {
  filename        = "${local.ansible_inventory_dir}/hosts.yml"
  file_permission = "0644"
  content = templatefile("${path.module}/templates/hosts.tmpl.yml", {
    prod_host = module.ec2_prod.public_ips[0]
    prod_key  = module.ec2_prod.ansible_private_key_path
    dev_host  = module.ec2_dev.public_ips[0]
    dev_key   = module.ec2_dev.ansible_private_key_path
    rds_host  = module.rds.address
    rds_port  = module.rds.port
    rds_user  = module.rds.username
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
