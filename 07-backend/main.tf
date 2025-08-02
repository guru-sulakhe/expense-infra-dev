# Here we are following an order for creating scalable backend server
# 1. Create EC2 instance backend server
# 2. Connect to the backend server using null resource and remote exec.
# 3. Copy the script into instance using provisioner "file" {}
# 4. Run Ansible Configuration
# 5. Capture AMI from the running EC2 instance backend server
# 6. Terminating Backend Server after capturing AMI 
# 7. Creating TargetGroup for HealthChecks 
# 8. Creating Launch Template with the Caputured AMI from the backend server
# 9. Creating Auto Scaling Group with the TargetGroup
# 10. Creating Auto Scaling policy
# 11. Creating Listener Rule for app-alb Load Balancer TargetGroup of backend server 

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

    connection { # connecting to backend EC2 server
        type     = "ssh"
        user     = "ec2-user"
        password = "DevOps321"
        host     = module.backend.private_ip
    }

    provisioner "file" { # copying backend.sh file to AWS EC2 server
        source      = "${var.common_tags.Component}.sh"
        destination = "/tmp/${var.common_tags.Component}.sh"
    }

    provisioner "remote-exec" { #Running backend.sh script inside the EC2 server
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

    provisioner "local-exec" { #Terminating backend-server EC2 instance by AWS CLI Commands
      command = "aws ec2 terminate-instances --instance-ids ${module.backend.id}"
    }
    depends_on = [aws_ami_from_instance.backend] 
}

# creating target group 
resource "aws_lb_target_group" "backend" {
  name     = "${var.project_name}-${var.environment}-${var.common_tags.Component}" #TargetGroup Name
  port     = 8080 #TargetGroup Port 
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
# Based on the launch template autoscaling group will be created, which will create multiple desired EC2 instances with the launch template configurations.
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

resource "aws_autoscaling_group" "bar" { # Newly created instances will be attached to the targetGroup by AutoScalingGroup
  name                      = "${var.project_name}-${var.environment}-${var.common_tags.Component}"
  max_size                  = 5 # 5 instances
  min_size                  = 1 # 1 instance
  health_check_grace_period = 60 # 60 seconds
  health_check_type         = "ELB"
  desired_capacity          = 1 # 1 instance
  target_group_arns = [aws_lb_target_group.backend.arn] # deploying  backend instance target group
    launch_template { #AutoScaling will take latest version 
    id      = aws_launch_template.backend.id #your launch template ID
    version = "$Latest"
  }
  vpc_zone_identifier       = split(",", data.aws_ssm_parameter.private_subnet_ids.value) #Selecting two private subnet ids

    instance_refresh {
    strategy = "Rolling" # Old instances will be deleted and new instances will be created
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["launch_template"] # This will be triggered only when launch template is created
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
    type             = "forward" #request will be forwarded to the respective Target Group
    target_group_arn = aws_lb_target_group.backend.arn
  }

  condition {
    host_header {
      values = ["backend.app-${var.environment}.${var.zone_name}"] # request will be sent to backend.app-dev.guru97s.cloud backend-server
    }
  }
}