variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "availability_zone" {
  description = "EBS 데이터 볼륨이 위치할 AZ"
  type        = string
}

variable "subnet" {
  description = "ASG가 사용할 Subnet ID"
  type        = list(string)
}

variable "instance_types" {
  description = "Spot 인스턴스 타입 목록"
  type        = list(string)
  default     = ["m7g.xlarge", "c7g.xlarge", "r7g.xlarge"]
}

variable "default_type" {
  description = "Launch Template의 기본 인스턴스 타입"
  type        = string
  default     = "m7g.xlarge"
}

variable "data_volume_tag" {
  description = "데이터 EBS 볼륨에 부여할 Tag:Name 값"
  type        = string
  default     = "myapp-data"
}

variable "ecr_repository_url" {
  description = "애플리케이션 Docker 이미지가 저장된 ECR 리포지토리 URL"
  type        = string
}

variable "alert_email" {
  description = "알림을 받을 이메일 주소"
  type        = string
}
