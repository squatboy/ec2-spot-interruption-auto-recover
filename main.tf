provider "aws" {
  region = var.region
}

# 사용자 정의 AMI 검색
data "aws_ami" "base" {
  owners      = ["self"]
  most_recent = true

  filter {
    name   = "tag:Name"
    values = ["myapp-base-v1"]
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

# Lambda 모듈 호출
module "lambda_backup" {
  source          = "./lambda"
  data_volume_tag = var.data_volume_tag
  region          = var.region
}
