output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

# 다른 모듈(ec2/rds)이 통째로 받아 쓰는 요약 객체.
output "summary" {
  value = {
    name_prefix        = local.name_prefix
    vpc_id             = aws_vpc.this.id
    vpc_cidr           = aws_vpc.this.cidr_block
    public_subnet_ids  = aws_subnet.public[*].id
    private_subnet_ids = aws_subnet.private[*].id
  }
}
