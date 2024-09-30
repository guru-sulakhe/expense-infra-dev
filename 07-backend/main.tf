module "backend" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  
  name = "${var.project_name}-${var.environment}-${var.common_tags.Component}"

  instance_type          = "t2.micro"
  vpc_security_group_ids = [data.aws_ssm_parameter.backend_sg_id.value]
  # convert StringList to string and get first element
  subnet_id              = local.private_subnet_id # selecting one public subnet from the list
  ami = data.aws_ami.ami_info.id
  tags = merge(
    var.common_tags,
    {
        Name = "${var.project_name}-${var.environment}-${var.common_tags.Component}"
    }
  )

}


# configuring backend server with ansible and running ansible scripts in the server internally
resource "null_resource" "backend" {
    triggers = {
      instance_id = module.backend.id # this will be triggered everytime instance is created
    }

    connection { # connecting to backend server
        type     = "ssh"
        user     = "ec2-user"
        password = "DevOps321"
        host     = module.backend.private_ip
    }

    provisioner "file" { # copying backend.sh file into server
        source      = "${var.common_tags.Component}.sh"
        destination = "/tmp/${var.common_tags.Component}.sh"
    }

    provisioner "remote-exec" { 
        inline = [
            "chmod +x /tmp/${var.common_tags.Component}.sh",
            "sudo sh /tmp/${var.common_tags.Component}.sh ${var.common_tags.Component} ${var.environment}"
        ]
    } 

}

# stopping the running server 
resource "aws_ec2_instance_state" "backend" {
  instance_id = module.backend.id
  state       = "stopped"
 # stop the server when null resource provisioning is completed
  depends_on = [null_resource.backend]
}

# capturing AMI from stopped server
resource "aws_ami_from_instance" "backend" {
  name               = "${var.project_name}-${var.environment}-${var.common_tags.Component}"
  source_instance_id = module.backend.id
  depends_on = [aws_ec2_instance_state.backend]
}

# deleting the backend server after capturing AMI
resource "null_resource" "backend_delete" {
    triggers = {
      instance_id = module.backend.id # this will be triggered everytime instance is created
    }

    connection {
        type     = "ssh"
        user     = "ec2-user"
        password = "DevOps321"
        host     = module.backend.private_ip
    }

    provisioner "local-exec" {
        command = "aws ec2 terminate-instances --instance-ids ${module.backend.id}"
    }
    depends_on = [aws_ami_from_instance.backend] 
}

# creating target group 
resource "aws_lb_target_group" "backend" {
  name     = "${var.project_name}-${var.environment}-${var.common_tags.Component}"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = data.aws_ssm_parameter.vpc_id.value

    health_check { # checking for 2 times under port whether the target grooup is healthy threshold or unhealthy threshold
    path                = "/health"
    port                = 8080
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

# creating launch template based on the AMI image ID
resource "aws_launch_template" "backend" {
  name = "${var.project_name}-${var.environment}-${var.common_tags.Component}"

  image_id = aws_ami_from_instance.backend.id

  instance_initiated_shutdown_behavior = "terminate"

  instance_type = "t3.micro"
  update_default_version = true # sets the latest version to default

  vpc_security_group_ids = [data.aws_ssm_parameter.backend_sg_id.value]

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      var.common_tags,
      {
        Name = "${var.project_name}-${var.environment}-${var.common_tags.Component}"
      }
    )
  }
}

resource "aws_autoscaling_group" "bar" {
  name                      = "${var.project_name}-${var.environment}-${var.common_tags.Component}"
  max_size                  = 5 # 5 instances
  min_size                  = 1 # 1 instance
  health_check_grace_period = 60 # 60 seconds
  health_check_type         = "ELB"
  desired_capacity          = 1 # 1 instance
  target_group_arns = [aws_lb_target_group.backend.arn] # deploying  backend instance target group
    launch_template {
    id      = aws_launch_template.backend.id
    version = "$Latest"
  }
  vpc_zone_identifier       = split(",", data.aws_ssm_parameter.private_subnet_ids.value)

    instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["launch_template"]
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.environment}-${var.common_tags.Component}"
    propagate_at_launch = true
  }

  timeouts {
    delete = "15m"
  }

  tag {
    key                 = "lorem"
    value               = "ipsum"
    propagate_at_launch = false
  }
}

# Adding autoscaling group policy
# Based on the policy the auto scaling will generate new instances (e.g AVERAGECPUUTILIZATION) 
resource "aws_autoscaling_policy" "backend" {
  name                   = "${var.project_name}-${var.environment}-${var.common_tags.Component}"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.bar.name

    target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization" # averagecpuutilization metric to autoscaling_group
    }

    target_value = 10.0
  }
}
# if you need backend.app-dev.guru97s.cloud to be enter into the backend server,then you need to add listener rule to the backend target group
# at which backend target group will navigate to the backend server whenever user enters backend.app-dev.guru97s.cloud in browser
# Adding listner_rule of app_alb_listener_arn to the backend target group 
resource "aws_lb_listener_rule" "static" {
  listener_arn = data.aws_ssm_parameter.app_alb_listener_arn.value
  priority     = 100 # less number will be validated first

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  condition {
    host_header {
      values = ["backend.app-${var.environment}.${var.zone_name}"] # backend.app-dev.guru97s.cloud
    }
  }
}