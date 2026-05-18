# Terraform

재사용 가능한 모듈과 환경별 엔트리포인트를 담는 폴더.

## 모듈 구성

- `modules/network`: VPC + public/private subnet + IGW + route table. **실제 AWS 리소스 단계.**
- `modules/ec2`: 앱 노드용 EC2 인스턴스 그룹 (placeholder).
- `modules/rds`: DB 인스턴스 + subnet group (placeholder).

## 환경

- `environments/dev`: 가장 먼저 띄울 dev 엔트리포인트.

## 상태

- provider: AWS 확정 (`environments/dev/providers.tf`).
- network 모듈: 실제 리소스 박힘.
- ec2 / rds 모듈: 아직 placeholder. 다음 단계에서 실제 리소스 추가 예정.
