output "summary" {
  value = {
    name_prefix          = local.name_prefix
    vpc_cidr             = var.vpc_cidr
    public_subnet_cidrs  = var.public_subnet_cidrs
    private_subnet_cidrs = var.private_subnet_cidrs
  }
}
