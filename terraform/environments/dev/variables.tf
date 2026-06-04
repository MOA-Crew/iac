variable "project_name" {
  description = "리소스 이름 prefix로 쓰이는 프로젝트 식별자"
  type        = string
  default     = "sw-hub"
}

variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "aws_profile" {
  description = "~/.aws/credentials 에 설정된 profile 이름. CI에서는 빈 문자열로 두고 환경변수로 인증."
  type        = string
  default     = "default"
}

variable "environment" {
  description = "배포 환경 이름 (dev/stage/prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "VPC 최상위 CIDR"
  type        = string
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "외부 진입용 public subnet CIDR 목록. 최소 2개 권장 (ALB/멀티AZ 대비)."
  type        = list(string)
  default     = ["10.10.1.0/24", "10.10.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "앱/DB가 들어갈 private subnet CIDR 목록. RDS subnet group이 ≥2 AZ를 요구해서 최소 2개."
  type        = list(string)
  default     = ["10.10.11.0/24", "10.10.12.0/24"]
}

variable "ec2_instance_count" {
  description = "생성할 EC2 app 노드 수"
  type        = number
  default     = 1
}

variable "ec2_instance_type" {
  description = "EC2 인스턴스 타입. t3.small = x86 2GB RAM. GH Actions 무료 러너가 x86이라 빌드 속도 위해 고정."
  type        = string
  default     = "t3.small"
}

variable "private_key_output_path" {
  description = "Terraform이 자동 생성한 SSH private key 저장 경로. 상대경로면 repo 루트 기준, 절대경로/~ 도 가능."
  type        = string
  default     = "sw-hub-dev.pem"
}

variable "ssh_allowed_cidr" {
  description = "SSH 접속 허용 CIDR. 키 기반 인증이라 0.0.0.0/0 사용해도 됨."
  type        = string
  default     = "0.0.0.0/0"
}

variable "rds_engine" {
  description = "RDS 엔진 (postgres / mysql 등). 실제 리소스 붙일 때 사용."
  type        = string
  default     = "postgres"
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID. 토큰과 분리해서 계정 교체가 쉽도록 변수로 받는다."
  type        = string
}

variable "cloudflare_zone_name" {
  description = "Cloudflare DNS zone name. TF_VAR_cloudflare_zone_name 환경변수로 주입한다."
  type        = string
}

variable "cloudflare_hostname" {
  description = "Cloudflare Tunnel로 노출할 전체 호스트명. TF_VAR_cloudflare_hostname 환경변수로 주입한다."
  type        = string
}

variable "cloudflare_tunnel_name" {
  description = "Cloudflare Tunnel 이름. 예: moa-dev"
  type        = string
  default     = "moa-dev"
}

variable "cloudflare_origin_service" {
  description = "Tunnel ingress origin service URL. EC2 connector가 host network면 localhost를 사용한다."
  type        = string
  default     = "http://localhost:8080"
}

variable "cloudflare_tunnel_secret" {
  description = "선택: Cloudflare Tunnel secret. null이면 Terraform이 random_id로 생성한다. 기존 tunnel import 시에는 기존 secret/상태 전략을 별도로 정한다."
  type        = string
  default     = null
  sensitive   = true
}
