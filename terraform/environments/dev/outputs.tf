output "network_summary" {
  description = "Planned network scaffold summary"
  value       = module.network.summary
}

output "compute_summary" {
  description = "Planned compute scaffold summary"
  value       = module.compute.summary
}
