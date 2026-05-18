variable "project_name" {
  description = "Project identifier used for naming"
  type        = string
  default     = "sw-hub"
}

variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "Primary network CIDR"
  type        = string
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.10.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.10.11.0/24"]
}

variable "app_node_count" {
  description = "Planned number of application nodes"
  type        = number
  default     = 2
}
