locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # private_key_output_path 해석 규칙:
  #   - 절대경로(/) 또는 ~ 로 시작 → pathexpand로 처리
  #   - 그 외(상대경로) → repo 루트 기준으로 해석.
  #     path.module = terraform/modules/ec2 이므로 3단계 위가 repo 루트.
  _key_path_is_absolute     = startswith(var.private_key_output_path, "/") || startswith(var.private_key_output_path, "~")
  resolved_private_key_path = local._key_path_is_absolute ? pathexpand(var.private_key_output_path) : "${path.module}/../../../${var.private_key_output_path}"
}

# 최신 Ubuntu 22.04 LTS AMI 자동 조회 (Canonical 공식 owner).
# amd64 — t3 등 x86 인스턴스용. GH Actions 무료 러너가 x86이라 빌드 속도 위해 이쪽 고정.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Terraform이 자동으로 SSH 키페어 생성. ED25519 (RSA보다 더 짧고 빠르고 안전).
# 주의: private key는 tfstate에 평문 저장됨. tfstate 파일 자체를 안전하게 관리해야 함.
resource "tls_private_key" "this" {
  algorithm = "ED25519"
}

# 생성된 public key를 AWS에 등록.
resource "aws_key_pair" "this" {
  key_name   = "${local.name_prefix}-key"
  public_key = tls_private_key.this.public_key_openssh
}

# 생성된 private key를 로컬 파일로 떨굼. ssh -i <이 파일> ubuntu@<IP> 로 바로 접속 가능.
resource "local_sensitive_file" "private_key" {
  filename        = local.resolved_private_key_path
  content         = tls_private_key.this.private_key_openssh
  file_permission = "0600"
}

# EC2 보안그룹. SSH는 키 기반 인증만 사용하므로 IP 제한은 운영자 판단에 위임.
resource "aws_security_group" "this" {
  name        = "${local.name_prefix}-ec2-sg"
  description = "Security group for ${local.name_prefix} app nodes"
  vpc_id      = var.network_summary.vpc_id

  ingress {
    description = "SSH (key-based auth only)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-ec2-sg"
  }
}

# 앱 노드. count로 N개 생성하고 public subnet들에 라운드로빈으로 분산.
resource "aws_instance" "this" {
  count = var.instance_count

  ami                  = data.aws_ami.ubuntu.id
  instance_type        = var.instance_type
  subnet_id            = var.network_summary.public_subnet_ids[count.index % length(var.network_summary.public_subnet_ids)]
  key_name             = aws_key_pair.this.key_name
  iam_instance_profile = var.iam_instance_profile

  vpc_security_group_ids = [aws_security_group.this.id]

  tags = {
    Name = "${local.name_prefix}-app-${count.index + 1}"
    Role = "app"
  }
}
