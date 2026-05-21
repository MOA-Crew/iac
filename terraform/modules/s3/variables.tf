variable "bucket_name" {
  description = "전역 유니크해야 하는 버킷 이름."
  type        = string
}

variable "versioning_enabled" {
  description = "객체 버전 관리. RAG 데이터처럼 무결성 중요한 버킷은 true 권장."
  type        = bool
  default     = false
}

variable "lifecycle_expiration_days" {
  description = "0이면 lifecycle 규칙 없음. >0이면 그 일수 경과한 객체 자동 만료 (백업 버킷 등)."
  type        = number
  default     = 0
}

variable "tags" {
  description = "버킷에 붙일 추가 태그."
  type        = map(string)
  default     = {}
}
