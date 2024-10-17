locals {
  private_subnet_id = element(split(",",data.aws_ssm_parameter.private_subnet_ids.value), 0)
}

# split() is used to convert stringList to list
# element() is used to select particular element from a list