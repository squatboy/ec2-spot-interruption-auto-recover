output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.app_asg.name
}

output "eip_public_ip" {
  description = "Elastic IP 주소"
  value       = aws_eip.server.public_ip
}
