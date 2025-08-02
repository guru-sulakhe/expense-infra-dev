resource "aws_acm_certificate" "expense" {
  domain_name       = "*.guru97s.cloud"
  validation_method = "DNS"


  tags = merge(
    var.common_tags,
    {
        Name = "${var.project_name}-${var.environment}"
    }
  )
}

resource "aws_route53_record" "expense" { #this will create a R53 record for the aws_acm_certificate.expense
  for_each = {
    for dvo in aws_acm_certificate.expense.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 1
  type            = each.value.type
  zone_id         = var.zone_id #Your AWS Hosted zone_id
}

resource "aws_acm_certificate_validation" "example" { #This will validates the aws_acm_certificate.expense
  certificate_arn         = aws_acm_certificate.expense.arn
  validation_record_fqdns = [for record in aws_route53_record.expense : record.fqdn]
}