locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# RDS는 subnet을 직접 가리키지 않고 subnet group을 통해 가리킴.
# subnet group은 ≥2 AZ를 강제하므로 private subnet 2개를 묶어 전달.
resource "aws_db_subnet_group" "this" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = var.network_summary.private_subnet_ids

  tags = {
    Name = "${local.name_prefix}-db-subnet-group"
  }
}

# DB master 비밀번호 자동 생성. 결과는 tfstate에 sensitive로 저장.
# RDS가 거부하는 특수문자(@ / " 공백 등) 제외.
resource "random_password" "db" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# RDS 보안그룹. 인바운드는 EC2 SG에서만, outbound는 RDS 내부 동작용으로 전체 허용.
resource "aws_security_group" "this" {
  name        = "${local.name_prefix}-rds-sg"
  description = "Security group for ${local.name_prefix} RDS"
  vpc_id      = var.network_summary.vpc_id

  ingress {
    description     = "DB port from app SG"
    from_port       = var.port
    to_port         = var.port
    protocol        = "tcp"
    security_groups = [var.app_security_group_id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-rds-sg"
  }
}

resource "aws_db_instance" "this" {
  identifier = "${local.name_prefix}-db"

  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.username
  password = random_password.db.result
  port     = var.port

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]

  publicly_accessible = false
  multi_az            = false

  # dev 편의 옵션: 백업 0일, destroy 시 최종 스냅샷 생략, 삭제 보호 해제.
  # 운영에선 이 셋 다 반대로 가야 함.
  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = {
    Name = "${local.name_prefix}-db"
  }
}
