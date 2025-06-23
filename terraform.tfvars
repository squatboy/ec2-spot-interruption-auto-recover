# AWS 리전 (서울)
region = "ap-northeast-2"

# EBS 볼륨 및 인스턴스가 생성될 가용 영역
availability_zone = "ap-northeast-2a"

# 1.2 단계에서 확인한 실제 서브넷 ID로 교체
private_subnets = ["subnet-09c8d4b6a9a238a7d"]

# 알림을 받을 실제 이메일 주소로 교체
alert_email = "[migonyoung01@gmail.com]"

# 프리 티어 사용을 위한 인스턴스 타입 설정
default_type   = "t2.micro"
instance_types = ["t2.micro"]

# 데이터 볼륨에 사용할 태그 이름 (기본값 사용 가능)
data_volume_tag = "spot-recovery-test-data"
