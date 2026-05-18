output "summary" {
  value = {
    name_prefix    = local.name_prefix
    app_node_count = var.app_node_count
    network_name   = var.network_summary.name_prefix
  }
}
