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
  default     = 2
}

variable "rds_engine" {
  description = "RDS 엔진 (postgres / mysql 등). 실제 리소스 붙일 때 사용."
  type        = string
  default     = "postgres"
}
