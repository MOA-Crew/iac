variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "instance_count" {
  description = "생성할 EC2 인스턴스 수"
  type        = number
}

variable "network_summary" {
  description = "network 모듈에서 넘겨주는 VPC/subnet 메타데이터"
  type        = any
}
