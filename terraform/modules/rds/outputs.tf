output "endpoint" {
  description = "DB 접속 주소 (host:port 형식)."
  value       = aws_db_instance.this.endpoint
}

output "address" {
  description = "DB 호스트명."
  value       = aws_db_instance.this.address
}

output "port" {
  value = aws_db_instance.this.port
}

output "db_name" {
  value = aws_db_instance.this.db_name
}

output "username" {
  value = aws_db_instance.this.username
}

output "password" {
  description = "DB master 비밀번호. terraform output -raw rds_password 로 조회."
  value       = random_password.db.result
  sensitive   = true
}

output "summary" {
  value = {
    name_prefix    = local.name_prefix
    engine         = "${var.engine} ${var.engine_version}"
    instance_class = var.instance_class
    endpoint       = aws_db_instance.this.endpoint
    db_name        = aws_db_instance.this.db_name
    username       = aws_db_instance.this.username
  }
}
