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

variable "instance_type" {
  description = "EC2 인스턴스 타입. t3.* = x86 (GH Actions 빌드 속도용), t4g.* = ARM. AMI 필터와 아키텍처 맞춰야 함."
  type        = string
  default     = "t3.small"
}

variable "private_key_output_path" {
  description = "Terraform이 자동 생성한 private key를 떨굴 경로. 상대경로면 repo 루트 기준. 절대경로(/)와 ~도 가능."
  type        = string
  default     = "sw-hub-dev.pem"
}

variable "ssh_allowed_cidr" {
  description = "SSH 접속 허용 CIDR. 키 기반 인증이라 0.0.0.0/0 도 가능하지만, 가능하면 본인 IP/32 권장."
  type        = string
  default     = "0.0.0.0/0"
}

variable "network_summary" {
  description = "network 모듈에서 넘겨주는 VPC/subnet 메타데이터"
  type        = any
}
