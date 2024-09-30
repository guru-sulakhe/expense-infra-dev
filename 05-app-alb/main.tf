resource "aws_lb" "app_alb" {
  name               = "${var.project_name}-${var.environment}-app-alb"
  internal           = true # because it is a private load balancer
  load_balancer_type = "application"
  security_groups    = [data.aws_ssm_parameter.app_alb_sg_id.value]
  subnets            = split("," ,data.aws_ssm_parameter.private_subnet_ids.value) # for APP ALB we need to select atleast two private subnets

  enable_deletion_protection = false


  tags = merge(
    var.common_tags,
    {
        Name = "${var.project_name}-${var.environment}-app-alb"
    }
  )

}

# Adding listener to app_alb which can accept connections from port 80 and adding fixed_reponse for displaying purpose
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
        type = "fixed-response"

    fixed_response {
      content_type = "text/html"
      message_body = "<h1> This is fixed response form APP ALB </h1>"
      status_code  = "200"
    }
  }
}

# Creating R53 record
 module "records" {
  source  = "terraform-aws-modules/route53/aws//modules/records"
  version = "~> 2.0"

  zone_name = var.zone_name

  records = [
    {
      name    = "*.app-${var.environment}"
      type    = "A" 
      allow_overwrite = true
      alias = {
        name = aws_lb.app_alb.dns_name
        zone_id = aws_lb.app_alb.zone_id
      }
    }
  ]

}