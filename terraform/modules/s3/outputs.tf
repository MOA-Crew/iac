output "bucket_id" {
  description = "버킷 이름."
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "버킷 ARN. IAM 정책에서 참조."
  value       = aws_s3_bucket.this.arn
}
