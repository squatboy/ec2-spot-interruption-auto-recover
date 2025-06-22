# 1) 공통 SNS 토픽
resource "aws_sns_topic" "spot_alerts" {
  name = "SpotRecoveryAlerts"
}

# 이메일 구독 (필요 시 여러 개 추가 가능)
resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.spot_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email # 실제 이메일은 tfvars 에 입력
}

# 2) Spot 중단 경고 → SNS
resource "aws_cloudwatch_event_rule" "spot_interrupt" {
  name        = "spot-interrupt-warning"
  description = "EC2 Spot Instance Interruption Warning to SNS"
  event_pattern = jsonencode({
    source = ["aws.ec2"]
    "detail-type" : ["EC2 Spot Instance Interruption Warning"]
  })
}

resource "aws_cloudwatch_event_target" "spot_interrupt_sns" {
  rule = aws_cloudwatch_event_rule.spot_interrupt.name
  arn  = aws_sns_topic.spot_alerts.arn
}

# 3) EC2 인스턴스에서 SNS 게시할 권한
# (user-data에서 '복구 완료' 메시지 전송)
data "aws_iam_policy_document" "ec2_sns_publish" {
  statement {
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.spot_alerts.arn]
  }
}

resource "aws_iam_role_policy" "ec2_inline_sns" {
  name   = "ec2-sns-publish"
  role   = aws_iam_role.ec2.name # ← 기존 EC2 역할 리소스
  policy = data.aws_iam_policy_document.ec2_sns_publish.json
}
