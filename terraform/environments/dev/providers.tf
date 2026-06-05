# AWS provider 설정.
# 인증 정보(access key)는 여기 절대 박지 않는다.
# Terraform이 아래 순서로 자동 탐색:
#   1) 환경변수: AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_PROFILE
#   2) ~/.aws/credentials 의 [profile] 블록  ← 로컬 개발 추천
#   3) EC2 instance profile / OIDC (CI 환경)
provider "aws" {
  region = var.aws_region
  # 로컬 개발: profile 사용. CI(OIDC): aws_profile=""로 두면 null이 되어 환경변수(임시자격증명)를 사용.
  profile = var.aws_profile != "" ? var.aws_profile : null

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Cloudflare provider 설정.
# API token은 CLOUDFLARE_API_TOKEN 환경변수로 주입한다.
# 계정/존/호스트명은 variables로 분리해서 도메인이나 터널 교체가 쉽도록 한다.
provider "cloudflare" {}
