variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "app_node_count" {
  type = number
}

variable "network_summary" {
  description = "Network metadata from the network module"
  type        = any
}
