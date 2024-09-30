resource "aws_ssm_parameter" "vpc_id" {
  name  = "/${var.project_name}/${var.environment}/vpc_id"
  type  = "String"
  value = module.vpc.vpc_id #vpc_id shoudld be included in outputs.tf of module vpc
}
resource "aws_ssm_parameter" "public_subnet_ids" {
  name  = "/${var.project_name}/${var.environment}/public_subnet_ids"
  type  = "StringList" # because of two subnets it will be a datatype of 2 tuple elements,since we should include StringList
  value = join(",",module.vpc.public_subnet_ids) # converting list to StringList 
}
# ["id1","id2"] ---> terraform format(2 subnets List datatype)
# [id1,id2] ---> ASW ssm format(2 subnets of StringList datatype )

resource "aws_ssm_parameter" "private_subnet_ids" {
  name  = "/${var.project_name}/${var.environment}/private_subnet_ids"
  type  = "StringList"
  value = join(",",module.vpc.private_subnet_ids) # converting list to StringList
}

# here aws_ssm_parameter will acts as the storage for the vpc_id of module vpc which can be useful for the extracting the data of vpc,sg,database
# thus it is essential to include vpc_id in the ssm parameter for the creation of parameter in aws.

resource "aws_ssm_parameter" "db_subnet_group_name" {
  name  = "/${var.project_name}/${var.environment}/db_subnet_group_name"
  type  = "String"
  value = module.vpc.database_subnet_group_name #vpc_id shoudld be included in outputs.tf of module vpc
}

