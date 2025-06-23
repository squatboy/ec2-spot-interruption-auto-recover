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

# EC2 인스턴스가 EIP를 연결할 수 있도록 정책 추가
resource "aws_iam_role_policy" "ec2_eip_policy" {
  name = "ec2-associate-eip-policy"
  role = aws_iam_role.ec2_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "ec2:AssociateAddress"
        Effect   = "Allow"
        Resource = "*" # 실제 환경에서는 특정 EIP ARN으로 제한하는 것이 좋습니다.
      },
    ]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name = "spot-app-instance-profile"
  role = aws_iam_role.ec2_role.name
}
