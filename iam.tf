# EC2 인스턴스 프로필 (SSM 사용)
resource "aws_iam_role" "ec2_role" {
  name = "spot-app-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ec2_ecr_readonly" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# User-data 스크립트가 EBS 볼륨을 연결하고 SNS 알림을 보낼 수 있도록 정책 추가
resource "aws_iam_role_policy" "ec2_runtime_permissions" {
  name = "ec2-runtime-permissions-policy"
  role = aws_iam_role.ec2_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:DescribeVolumes",
          "ec2:AttachVolume"
        ]
        Effect   = "Allow"
        Resource = "*" # 실제 운영 환경에서는 특정 볼륨 ARN으로 제한하는 것이 좋습니다.
      },
      {
        Action   = "sns:Publish"
        Effect   = "Allow"
        Resource = "arn:aws:sns:*:*:SpotRecoveryAlerts" # 생성될 SNS 토픽 ARN
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name = "spot-app-instance-profile"
  role = aws_iam_role.ec2_role.name
}
