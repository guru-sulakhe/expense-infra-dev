resource "aws_key_pair" "vpn" { # using openvpn AMI in order to create vpn instance
  key_name   = "open-vpn"
  # you can paste public key like this
  # public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO04/uDF2DAw9J1VVt7aytr3xj9Tekmhbc4cVSk8sJ3k guruv@DESKTOP-K50A3PF"
  public_key = file("~/.ssh/openvpn.pub") # ~ means windows home directory
}

module "vpn" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  
  key_name = aws_key_pair.vpn.key_name
  name = "${var.project_name}-${var.environment}-vpn"

  instance_type          = "t2.micro"
  vpc_security_group_ids = [data.aws_ssm_parameter.vpn_sg_id.value]
  # convert StringList to string and get first element
  subnet_id              = local.public_subnet_id # selecting one public subnet from the list
  ami = data.aws_ami.ami_info.id
  tags = merge(
    var.common_tags,
    {
        Name = "${var.project_name}-${var.environment}-vpn"
    }
  )

}