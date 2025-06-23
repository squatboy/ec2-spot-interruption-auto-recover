output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.app_asg.name
}

output "spot_alerts_topic_arn" {
  value       = aws_sns_topic.spot_alerts.arn
  description = "SNS 토픽 ARN (Slack 웹훅 등 추가 구독 시 활용)"
}
