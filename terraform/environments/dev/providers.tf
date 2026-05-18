# AWS provider 설정.
# 인증 정보(access key)는 여기 절대 박지 않는다.
# Terraform이 아래 순서로 자동 탐색:
#   1) 환경변수: AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_PROFILE
#   2) ~/.aws/credentials 의 [profile] 블록  ← 로컬 개발 추천
#   3) EC2 instance profile / OIDC (CI 환경)
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
