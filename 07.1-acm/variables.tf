variable "project_name" {
    default = "expense"
}
variable "environment" {
    default = "dev"
}
variable "common_tags" {
    default = {
        Project = "expense"
        Terraform = "true"
        Enviroment = "dev"
        Component = "backend"
    }
}
variable "zone_name" {
    default = "guru97s.cloud"
}
variable "zone_id" {
    default = "Z08273698E2G6XTP9T7C"
}