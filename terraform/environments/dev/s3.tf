# S3 버킷. 전부 private (BPA + 암호화). 용도별로 분리.
# 버킷 이름은 전역 유니크해야 해서 account id를 접미사로 붙임.

data "aws_caller_identity" "current" {}

locals {
  s3_buckets = {
    uploads = {
      versioning_enabled        = false
      lifecycle_expiration_days = 0 # 영구 보관
    }
    backups = {
      versioning_enabled        = false
      lifecycle_expiration_days = 90 # 90일 경과 객체 자동 삭제
    }
  }
}

module "s3" {
  source   = "../../modules/s3"
  for_each = local.s3_buckets

  bucket_name               = "${var.project_name}-${var.environment}-${each.key}-${data.aws_caller_identity.current.account_id}"
  versioning_enabled        = each.value.versioning_enabled
  lifecycle_expiration_days = each.value.lifecycle_expiration_days
}
