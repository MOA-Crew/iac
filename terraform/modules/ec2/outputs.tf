output "summary" {
  value = {
    name_prefix    = local.name_prefix
    instance_count = var.instance_count
    network_name   = var.network_summary.name_prefix
  }
}
