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
  description = "엔진 버전. 16.8 등 마이너 버전은 2026-05 deprecation 대상이라 16.11+ 사용."
  type        = string
  default     = "16.11"
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

variable "app_security_group_ids" {
  description = "이 RDS에 접근 허용할 앱(EC2) 보안그룹 ID 목록. 여러 박스(prod/dev)가 한 RDS를 공유할 때 각 SG를 모두 넣는다."
  type        = list(string)
}

variable "network_summary" {
  description = "network 모듈에서 넘겨주는 VPC/subnet 메타데이터"
  type        = any
}
