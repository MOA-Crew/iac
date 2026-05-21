# EC2가 S3에 접근할 때 정적 키 대신 instance profile을 쓰기 위한 IAM 구성.
# 흐름: EC2 --(assume)--> app role --(정책)--> 위 S3 버킷에만 객체 R/W.

# 1) EC2 서비스가 이 role을 assume할 수 있게 허용.
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "${var.project_name}-${var.environment}-app-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

# 2) 우리가 만든 버킷들에 한정된 권한만 부여 (최소권한).
data "aws_iam_policy_document" "s3_access" {
  statement {
    sid       = "ListOwnBuckets"
    actions   = ["s3:ListBucket"]
    resources = [for b in module.s3 : b.bucket_arn]
  }
  statement {
    sid = "ObjectReadWrite"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [for b in module.s3 : "${b.bucket_arn}/*"]
  }
}

resource "aws_iam_role_policy" "s3_access" {
  name   = "s3-access"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.s3_access.json
}

# 3) role을 EC2에 붙일 수 있는 형태(instance profile)로 래핑.
resource "aws_iam_instance_profile" "app" {
  name = "${var.project_name}-${var.environment}-app-profile"
  role = aws_iam_role.app.name
}
