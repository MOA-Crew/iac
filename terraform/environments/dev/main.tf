module "network" {
  source = "../../modules/network"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "compute" {
  source = "../../modules/compute"

  project_name    = var.project_name
  environment     = var.environment
  app_node_count  = var.app_node_count
  network_summary = module.network.summary
}
