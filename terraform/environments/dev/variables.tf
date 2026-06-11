variable "project_name" {
  description = "공유 인프라(VPC/IAM/S3) 이름 prefix. 기존 sw-hub 유지(개명=재생성, CI role IAM 스코프도 sw-hub-*)."
  type        = string
  default     = "sw-hub"
}

variable "app_project_name" {
  description = "앱 박스(EC2)와 RDS 이름 prefix. 보존할 데이터가 없어 moa-* 로 깨끗이 새로 생성. EC2/RDS는 이름 제한 없는 IAM 액션이라 sw-hub-* CI role로도 생성 가능."
  type        = string
  default     = "moa"
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

variable "ec2_instance_type_prod" {
  description = "prod 박스 인스턴스 타입. 실서비스라 t3.small(2GB)."
  type        = string
  default     = "t3.small"
}

variable "ec2_instance_type_dev" {
  description = "dev 박스 인스턴스 타입. 테스트라 t3.micro(1GB, 프리티어). JVM 힙 축소(-Xmx384m)+zram 전제."
  type        = string
  default     = "t3.micro"
}

variable "private_key_output_path_prod" {
  description = "prod 박스 SSH private key 저장 경로. 상대경로면 repo 루트 기준."
  type        = string
  default     = "moa-prod.pem"
}

variable "private_key_output_path_dev" {
  description = "dev 박스 SSH private key 저장 경로. 상대경로면 repo 루트 기준."
  type        = string
  default     = "moa-dev.pem"
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

variable "rds_db_name" {
  description = "공유 RDS의 초기 database. prod가 이걸 사용. dev용 moa_dev는 Ansible이 추가 생성."
  type        = string
  default     = "moa_prod"
}

variable "rds_username" {
  description = "RDS master 사용자명."
  type        = string
  default     = "moa_admin"
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID. 토큰과 분리해서 계정 교체가 쉽도록 변수로 받는다."
  type        = string
}

variable "cloudflare_zone_name" {
  description = "Cloudflare DNS zone name. TF_VAR_cloudflare_zone_name 환경변수로 주입한다."
  type        = string
}

variable "cloudflare_hostname_prod" {
  description = "prod 공개 호스트명. TF_VAR_cloudflare_hostname_prod 로 주입(예: moa.yeoun.org)."
  type        = string

  validation {
    # 빈 값이면 CI에서 미설정 secret이 ""로 치환돼 들어온 것. TF_VAR=""는 '설정됨'으로 취급돼
    # required 체크를 통과하고, RDS 등이 먼저 생성된 뒤 Cloudflare 단계에서야 깨지는 부분 apply가 된다.
    # plan 단계에서 차단해 그 절반-적용을 막는다.
    condition     = length(trimspace(var.cloudflare_hostname_prod)) > 0
    error_message = "cloudflare_hostname_prod 가 비어 있습니다. repo secret TF_VAR_CLOUDFLARE_HOSTNAME_PROD(예: moa.yeoun.org)를 설정하세요."
  }
}

variable "cloudflare_hostname_dev" {
  description = "dev 공개 호스트명. TF_VAR_cloudflare_hostname_dev 로 주입(예: dev-moa.yeoun.org)."
  type        = string

  validation {
    condition     = length(trimspace(var.cloudflare_hostname_dev)) > 0
    error_message = "cloudflare_hostname_dev 가 비어 있습니다. repo secret TF_VAR_CLOUDFLARE_HOSTNAME_DEV(예: dev-moa.yeoun.org)를 설정하세요."
  }
}

variable "cloudflare_origin_service" {
  description = "Tunnel ingress origin service URL. EC2 connector가 host network면 localhost를 사용한다."
  type        = string
  default     = "http://localhost:8080"
}
