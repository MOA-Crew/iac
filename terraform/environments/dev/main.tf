# 공유 네트워크. project_name 은 sw-hub 유지(VPC/IAM/S3 와 동일 네이밍).
module "network" {
  source = "../../modules/network"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

# 앱 박스 2대 — EC2/RDS 만 moa-* 네이밍(var.app_project_name).
# prod = 실서비스(moa.yeoun.org), dev = 테스트(dev-moa.yeoun.org). 같은 VPC, 별도 SG/키페어.
module "ec2_prod" {
  source = "../../modules/ec2"

  project_name            = var.app_project_name
  environment             = "prod"
  instance_count          = 1
  instance_type           = var.ec2_instance_type_prod
  private_key_output_path = var.private_key_output_path_prod
  ssh_allowed_cidr        = var.ssh_allowed_cidr
  network_summary         = module.network.summary
  iam_instance_profile    = aws_iam_instance_profile.app.name
}

module "ec2_dev" {
  source = "../../modules/ec2"

  project_name            = var.app_project_name
  environment             = "dev"
  instance_count          = 1
  instance_type           = var.ec2_instance_type_dev
  private_key_output_path = var.private_key_output_path_dev
  ssh_allowed_cidr        = var.ssh_allowed_cidr
  network_summary         = module.network.summary
  iam_instance_profile    = aws_iam_instance_profile.app.name
}

# 공유 RDS 인스턴스(moa-prod-db). 내부에 database 2개(moa_prod / moa_dev).
# 두 박스 SG 모두 DB 포트 허용. moa_dev database 는 Ansible 이 추가 생성.
module "rds" {
  source = "../../modules/rds"

  project_name = var.app_project_name
  environment  = "prod"
  engine       = var.rds_engine
  db_name      = var.rds_db_name
  username     = var.rds_username
  app_security_group_ids = [
    module.ec2_prod.security_group_id,
    module.ec2_dev.security_group_id,
  ]
  network_summary = module.network.summary
}
