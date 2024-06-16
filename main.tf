provider "aws" {
  region = "eu-central-1"
}

resource "aws_launch_template" "web_server" {
  name = "web-server-launch-template"

  instance_type = "t2.micro"

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = 8
    }
  }

  image_id = "ami-00975bcf7116d087c"
}

resource "aws_autoscaling_group" "web_server_asg" {
  launch_template {
    id      = aws_launch_template.web_server.id
    version = "$Latest"
  }

  min_size         = 1
  max_size         = 10
  desired_capacity = 1

  vpc_zone_identifier = ["subnet-0123456789abcdef0"]

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 1
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy                 = "lowest-price"
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.web_server.id
        version            = "$Latest"
      }

      overrides {
        instance_type = "t3.micro"
      }

      overrides {
        instance_type = "t3a.micro"
      }
    }
  }

  tag {
    key                 = "Name"
    value               = "web-server-instance"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "scale_up_cpu" {
  name                   = "scale_up_cpu"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.web_server_asg.name

  policy_type = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 50.0
  }
}

resource "aws_cloudwatch_metric_alarm" "request_count_high" {
  alarm_name                = "request_count_high"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = "2"
  metric_name               = "RequestCount"
  namespace                 = "AWS/ApplicationELB"
  period                    = "60"
  statistic                 = "Sum"
  threshold                 = "1000"
  alarm_actions             = [aws_autoscaling_policy.scale_up_requests.arn]
  dimensions = {
    LoadBalancer = "app/hsal27/50dc6c495c0c9188"
  }
}

resource "aws_autoscaling_policy" "scale_up_requests" {
  name                   = "scale_up_requests"
  scaling_adjustment     = 1
  adjustment_type        = "PercentChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.web_server_asg.name

  policy_type = "StepScaling"
  step_adjustment {
    metric_interval_lower_bound = 0
    scaling_adjustment          = 2  # Double the capacity
  }

  step_adjustment {
    metric_interval_lower_bound = 1000
    scaling_adjustment          = 3  # Triple the capacity
  }
}

output "autoscaling_group_name" {
  value = aws_autoscaling_group.web_server_asg.name
}