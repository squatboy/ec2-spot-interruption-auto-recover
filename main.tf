provider "aws" {
  region = var.region
}

# 사용자 정의 AMI 검색 (CI/CD에서 관리하는 myapp-base-*)
data "aws_ami" "base" {
  owners      = ["self"]
  most_recent = true

  filter {
    name   = "tag:Name"
    values = ["myapp-base-*"]
  }
}

# 독립 데이터 볼륨 생성
resource "aws_ebs_volume" "data" {
  availability_zone = var.availability_zone
  size              = 20
  tags = {
    Name = var.data_volume_tag
  }
}

# Elastic IP
resource "aws_eip" "server" {
  domain = "vpc"
  tags   = { Name = "app-eip" }
}

# Lambda 모듈 호출
module "lambda_backup" {
  source          = "./lambda"
  data_volume_tag = var.data_volume_tag
  allocation_id   = aws_eip.server.allocation_id
  region          = var.region
}
