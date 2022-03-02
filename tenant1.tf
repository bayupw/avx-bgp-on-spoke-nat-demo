# ---------------------------------------------------------------------------------------------------------------------
# Tenant 1
# ---------------------------------------------------------------------------------------------------------------------

# Tenant-1 Landing Spoke
module "aws_tenant_1" {
  source          = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  cloud           = "AWS"
  name            = "Landing-Tenant1-Spoke"
  cidr            = cidrsubnet(var.cloud_supernet, 16, 101)
  region          = var.aws_region
  account         = var.aws_account
  transit_gw      = module.aws_transit_1.transit_gateway.gw_name
  insane_mode     = var.hpe
  instance_size   = var.aws_instance_size
  ha_gw           = var.ha_gw
  enable_bgp      = true
  local_as_number = 65001
  security_domain = aviatrix_segmentation_security_domain.tenant1_segmentation_security_domain.domain_name

  depends_on = [module.aws_transit_1]

  ###############################
  # BGP Route Approval Sections #
  ###############################
  enable_learned_cidrs_approval = true
  approved_learned_cidrs        = [cidrsubnet(var.tenant_cidr, 4, 0), cidrsubnet(var.tenant_cidr, 4, 1)]
}


# Tenant 1 On-Prem VPC
module "tenant_1_onprem_vpc" {
  source          = "terraform-aws-modules/vpc/aws"
  version         = "~> 3.0"
  name            = "Tenant1-On-Prem"
  cidr            = var.tenant_cidr
  azs             = ["${var.aws_region}a"]
  public_subnets  = [cidrsubnet(var.tenant_cidr, 4, 1)] # "192.168.200.16/28"
  private_subnets = [cidrsubnet(var.tenant_cidr, 4, 0)] # "192.168.200.0/28"
  enable_ipv6     = false
}

# Tenant1 On-Prem CSR
module "tenant_1_onprem_csr" {
  source             = "github.com/bayupw/avx-bgp-on-spoke-s2c"
  hostname           = "Tenant1-Router"
  tunnel_proto       = "IPsec"
  network_cidr       = var.tenant_cidr
  public_subnet_ids  = [module.tenant_1_onprem_vpc.public_subnets[0]]
  private_subnet_ids = [module.tenant_1_onprem_vpc.private_subnets[0]]
  instance_type      = "t3.medium"
  public_conns       = ["${module.aws_tenant_1.spoke_gateway.gw_name}:${module.aws_tenant_1.spoke_gateway.local_as_number}:1"]
  csr_bgp_as_num     = "65011"
  create_client      = false
  key_name           = var.existing_key_name == null ? "${random_string.key_random_id[0].id}_key_pair" : var.existing_key_name
  depends_on         = [module.aws_tenant_1, module.tenant_1_onprem_vpc]
}


# ---------------------------------------------------------------------------------------------------------------------
# Tenant1 On-Prem AWS EC2
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "tenant1_instance_sg" {
  name        = "tenant1/sg-instance"
  description = "Allow all traffic from VPCs inbound and all outbound"
  vpc_id      = module.tenant_1_onprem_vpc.vpc_id

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
    Name = "tenant1/sg-instance"
  }
}

resource "aws_instance" "tenant1_instance" {
  ami                         = data.aws_ami.amazon_linux_2.id
  subnet_id                   = module.tenant_1_onprem_vpc.private_subnets[0]
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.tenant1_instance_sg.id]
  associate_public_ip_address = false
  key_name                    = var.existing_key_name == null ? "${random_string.key_random_id[0].id}_key_pair" : var.existing_key_name
  iam_instance_profile        = var.existing_ssm_instance_profile == null && var.create_ssm_profile ? aws_iam_instance_profile.ssm_instance_profile[0].name : var.existing_ssm_instance_profile

  user_data = <<EOF
#!/bin/bash
sudo sed 's/PasswordAuthentication no/PasswordAuthentication yes/' -i /etc/ssh/sshd_config
sudo systemctl restart sshd
echo ec2-user:${var.vm_admin_password} | sudo chpasswd
EOF

  tags = {
    Name = "tenant1-instance"
  }
  #user_data = file("install-nginx.sh")
}