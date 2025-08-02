resource "aws_lb" "web_alb" {
  name               = "${var.project_name}-${var.environment}-web-alb"
  internal           = false # because it is a public load balancer
  load_balancer_type = "application"
  security_groups    = [data.aws_ssm_parameter.web_alb_sg_id.value]
  subnets            = split("," ,data.aws_ssm_parameter.public_subnet_ids.value) # for WEB ALB we need to select atleast two private subnets

  enable_deletion_protection = false


  tags = merge(
    var.common_tags,
    {
        Name = "${var.project_name}-${var.environment}-web-alb"
    }
  )

}

# Adding listener to app_alb which can accept connections from port 80
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
        type = "fixed-response"

    fixed_response {
      content_type = "text/html"
      message_body = "<h1> This is fixed response form WEB ALB </h1>"
      status_code  = "200"
    }
  }
}

resource "aws_lb_listener" "https" { #creating load balancer listener rule for the HTTPS ACM certificate
  load_balancer_arn = aws_lb.web_alb.arn
  port              = "443"

  protocol          = "HTTPS"
  certificate_arn   = data.aws_ssm_parameter.acm_certificate_arn.value
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  default_action {
        type = "fixed-response"

    fixed_response {
      content_type = "text/html"
      message_body = "<h1> This is fixed response form WEB ALB HTTPS</h1>"
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
      name    = "web-${var.environment}" # web-dev
      type    = "A"  
      allow_overwrite = true
      alias = {
        name = aws_lb.web_alb.dns_name
        zone_id = aws_lb.web_alb.zone_id
      }
    }
  ]

}