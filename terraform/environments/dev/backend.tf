# Terraform 상태를 S3에 저장하는 원격 백엔드.
# CI 러너는 매번 새로 뜨는 일회용이라, 공유 상태를 S3에서 읽고/쓰기 위해 필수.
# 잠금은 S3 네이티브 락파일(use_lockfile)을 사용 — 별도 DynamoDB 테이블 불필요(Terraform 1.10+).
# 버킷은 부트스트랩 단계에서 별도로 생성한다(버전관리/암호화/퍼블릭차단 적용).
terraform {
  backend "s3" {
    bucket       = "sw-hub-dev-tfstate-850919911012"
    key          = "dev/terraform.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true
  }
}
