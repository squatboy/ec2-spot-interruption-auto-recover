# Spot용 Launch Template
resource "aws_launch_template" "app" {
  name_prefix   = "spot-app-"
  image_id      = data.aws_ami.base.id
  instance_type = var.default_type
  key_name      = "spot-instance-key"

  user_data = base64encode(templatefile("${path.module}/userdata.tpl", {
    volume_tag         = var.data_volume_tag
    ecr_repository_url = var.ecr_repository_url
  }))

  # Public IP를 할당 허용
  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination       = true
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      delete_on_termination = true
    }
  }
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  # EBS 볼륨이 완전히 생성된 후에 Launch Template이 생성되도록 의존성 추가
  depends_on = [
    aws_ebs_volume.data
  ]
}

# Auto Scaling Group (Spot + capacity_rebalance)
resource "aws_autoscaling_group" "app_asg" {
  name                      = "spot-app-asg"
  max_size                  = 1
  min_size                  = 1
  desired_capacity          = 1
  health_check_type         = "EC2"
  health_check_grace_period = 60
  capacity_rebalance        = true

  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.app.id
        version            = "$Latest"
      }

      dynamic "override" {
        for_each = var.instance_types
        content {
          instance_type = override.value
        }
      }
    }

    instances_distribution {
      spot_allocation_strategy = "capacity-optimized-prioritized"
    }
  }

  vpc_zone_identifier = var.subnet
  tag {
    key                 = "Name"
    value               = "spot-app-instance"
    propagate_at_launch = true
  }
}
