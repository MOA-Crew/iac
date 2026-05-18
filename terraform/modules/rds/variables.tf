variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "engine" {
  description = "DB 엔진 (postgres / mysql 등)"
  type        = string
  default     = "postgres"
}

variable "engine_version" {
  description = "엔진 버전. postgres는 16.3 권장."
  type        = string
  default     = "16.8"
}

variable "instance_class" {
  description = "RDS 인스턴스 클래스."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "스토리지 GB. RDS 최소 20."
  type        = number
  default     = 20
}

variable "db_name" {
  description = "RDS 생성 시 함께 만들 초기 데이터베이스 이름."
  type        = string
  default     = "swhub"
}

variable "username" {
  description = "DB master 사용자 이름."
  type        = string
  default     = "swhub_admin"
}

variable "port" {
  description = "DB 포트. postgres=5432, mysql=3306."
  type        = number
  default     = 5432
}

variable "app_security_group_id" {
  description = "이 RDS에 접근 허용할 앱(EC2) 보안그룹 ID."
  type        = string
}

variable "network_summary" {
  description = "network 모듈에서 넘겨주는 VPC/subnet 메타데이터"
  type        = any
}
