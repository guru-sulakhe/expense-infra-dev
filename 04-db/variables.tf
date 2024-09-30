variable "project_name" {
    default = "expense"
}
variable "environment" {
    default = "dev"
}
variable "common_tags" {
    default = {
        Project = "expense"
        Enviroment = "dev"
        Terraform = "true"
    }
}
variable "zone_name" {
    default = "guru97s.cloud"
}