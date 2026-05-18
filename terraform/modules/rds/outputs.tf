output "summary" {
  value = {
    name_prefix  = local.name_prefix
    engine       = var.engine
    network_name = var.network_summary.name_prefix
  }
}
