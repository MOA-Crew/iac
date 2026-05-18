module "network" {
  source = "../../modules/network"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "ec2" {
  source = "../../modules/ec2"

  project_name    = var.project_name
  environment     = var.environment
  instance_count  = var.ec2_instance_count
  network_summary = module.network.summary
}

module "rds" {
  source = "../../modules/rds"

  project_name    = var.project_name
  environment     = var.environment
  engine          = var.rds_engine
  network_summary = module.network.summary
}
