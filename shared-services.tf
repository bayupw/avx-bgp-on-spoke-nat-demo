# ---------------------------------------------------------------------------------------------------------------------
# Shared Services
# ---------------------------------------------------------------------------------------------------------------------

# Shared Services VPC and Spoke Gateways
module "aws_shared_services" {
  source          = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  cloud           = "AWS"
  name            = "Shared-Services"
  cidr            = cidrsubnet(var.cloud_supernet, 16, 100) # "10.0.100.0/24"
  region          = var.aws_region
  account         = var.aws_account
  transit_gw      = module.aws_transit_1.transit_gateway.gw_name
  insane_mode     = var.hpe
  instance_size   = var.aws_instance_size
  ha_gw           = var.ha_gw
  depends_on      = [module.aws_transit_1]
  security_domain = aviatrix_segmentation_security_domain.sharedservices_segmentation_security_domain.domain_name
  #included_advertised_spoke_routes = "10.0.100.0/24,10.0.200.0/24" # Advertise Shared Services Real CIDR & Virtual CIDR
}

# ---------------------------------------------------------------------------------------------------------------------
# Shared Services AWS EC2
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "sharedservices_instance_sg" {
  name        = "sharedservices/sg-instance"
  description = "Allow all traffic from VPCs inbound and all outbound"
  vpc_id      = module.aws_shared_services.vpc.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/8","172.16.0.0/12","192.168.0.0/16"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "sharedservices/sg-instance"
  }
}

resource "aws_instance" "sharedservices_instance" {
  ami                         = data.aws_ami.amazon_linux_2.id
  subnet_id                   = module.aws_shared_services.vpc.public_subnets[0].subnet_id
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.sharedservices_instance_sg.id]
  associate_public_ip_address = true
  key_name                    = var.existing_key_name == null ? "${random_string.key_random_id.id}_key_pair" : var.existing_key_name
  iam_instance_profile        = var.existing_ssm_instance_profile == null && var.create_ssm_profile ? aws_iam_instance_profile.ssm_instance_profile[0].name : var.existing_ssm_instance_profile

  user_data = <<EOF
#!/bin/bash
sudo sed 's/PasswordAuthentication no/PasswordAuthentication yes/' -i /etc/ssh/sshd_config
sudo systemctl restart sshd
echo ec2-user:${var.vm_admin_password} | sudo chpasswd
EOF

  tags = {
    Name = "sharedservices-instance"
  }
  #user_data = file("install-nginx.sh")
}