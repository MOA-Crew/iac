variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "engine" {
  description = "DB 엔진 종류 (예: postgres, mysql). 아직 placeholder 단계라 값만 전달."
  type        = string
}

variable "network_summary" {
  description = "RDS subnet group을 만들 때 쓰일 network 메타데이터"
  type        = any
}
