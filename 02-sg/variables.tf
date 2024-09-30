variable "project_name" {
    default = "expense"
}
variable "environment" {
    default = "dev"
}
variable "common_tags" {
    type = map
    default = {
        Project = "expense"
        Enviroment = "dev"
        Terraform = true
    }
}
variable "vpn_sg_rules" {
    default = [
        {
            from_port = 943
            to_port = 943
            protocol = "tcp" # all protocols
            cidr_blocks = ["0.0.0.0/0"]
        },
        {
            from_port = 443
            to_port = 443
            protocol = "tcp" # all protocols
            cidr_blocks = ["0.0.0.0/0"]
        },
        {
            from_port = 22
            to_port = 22
            protocol = "tcp" # all protocols
            cidr_blocks = ["0.0.0.0/0"]
        },
        {
            from_port = 1194
            to_port = 1194
            protocol = "udp" # all protocols
            cidr_blocks = ["0.0.0.0/0"]
        }
    ]
}