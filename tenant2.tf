# ---------------------------------------------------------------------------------------------------------------------
# Tenant 2
# ---------------------------------------------------------------------------------------------------------------------

# Tenant-2 Landing Spoke
module "aws_tenant_2" {
  source                           = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  cloud                            = "AWS"
  name                             = "Landing-Tenant2-Spoke"
  cidr                             = cidrsubnet(var.cloud_supernet, 16, 102)
  region                           = var.aws_region
  account                          = var.aws_account
  transit_gw                       = module.aws_transit_1.transit_gateway.gw_name
  insane_mode                      = var.hpe
  instance_size                    = var.aws_instance_size
  ha_gw                            = var.ha_gw
  enable_bgp                       = true
  local_as_number                  = 65002
  security_domain                  = aviatrix_segmentation_security_domain.tenant2_segmentation_security_domain.domain_name
  included_advertised_spoke_routes = "${cidrsubnet(var.cloud_supernet, 16, 102)},${var.tenant_2_virtual_host}" # Advertise Spoke VPC and Virtual Host Tenant-2 Host /32

  depends_on = [module.aws_transit_1]

  ###############################
  # BGP Route Approval Sections #
  ###############################
  enable_learned_cidrs_approval = true
  approved_learned_cidrs        = [cidrsubnet(var.tenant_cidr, 4, 2), cidrsubnet(var.tenant_cidr, 4, 3)]
  # spoke_bgp_manual_advertise_cidrs = ["10.0.102.0/24,10.0.100.0/24"]   # Advertise Spoke VPC and Shared Services VPC
}

# Tenant 2 On-Prem VPC
module "tenant_2_onprem_vpc" {
  source               = "terraform-aws-modules/vpc/aws"
  version              = "~> 3.0"
  name                 = "Tenant2-On-Prem"
  cidr                 = var.tenant_cidr
  azs                  = ["${var.aws_region}a"]
  public_subnets       = [cidrsubnet(var.tenant_cidr, 4, 3)] # 192.168.200.48/28
  private_subnets      = [cidrsubnet(var.tenant_cidr, 4, 2)] # 192.168.200.32/28
  enable_ipv6          = false
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# Tenant-2 On-Prem - Overlaps with Tenant-1 On-Prem
module "tenant_2_onprem_csr" {
  source             = "github.com/bayupw/avx-bgp-on-spoke-s2c"
  hostname           = "Tenant2-Router"
  tunnel_proto       = "IPsec"
  network_cidr       = var.tenant_cidr
  public_subnet_ids  = [module.tenant_2_onprem_vpc.public_subnets[0]]
  private_subnet_ids = [module.tenant_2_onprem_vpc.private_subnets[0]]
  instance_type      = "t3.medium"
  public_conns       = ["${module.aws_tenant_2.spoke_gateway.gw_name}:${module.aws_tenant_2.spoke_gateway.local_as_number}:1"]
  csr_bgp_as_num     = "65012"
  create_client      = false
  depends_on         = [module.aws_tenant_2, module.tenant_2_onprem_vpc]
}


# ---------------------------------------------------------------------------------------------------------------------
# Tenant1 On-Prem AWS EC2
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "tenant2_instance_sg" {
  name        = "tenant2/sg-instance"
  description = "Allow all traffic from VPCs inbound and all outbound"
  vpc_id      = module.tenant_2_onprem_vpc.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
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

resource "aws_route" "tenant2_route_to_csr" {
  route_table_id         = module.tenant_2_onprem_vpc.private_route_table_ids[0]
  destination_cidr_block = "10.0.0.0/8"
  network_interface_id   = module.tenant_2_onprem_csr.CSR_Private_ENI[0].id
  depends_on             = [module.tenant_2_onprem_csr]
}

# SSM Tenant1
resource "aws_security_group" "tenant2_endpoint_sg" {
  name        = "ssm-tenant2-endpoints-sg"
  description = "Allow TLS inbound traffic for SSM/EC2 endpoints"
  vpc_id      = module.tenant_2_onprem_vpc.vpc_id

  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.tenant_2_onprem_vpc.vpc_cidr_block]
  }
  tags = {
    Name = "sg-ssm-tenant2-endpoints"
  }
}

resource "aws_vpc_endpoint" "tenant2_ssm_endpoint" {
  vpc_id              = module.tenant_2_onprem_vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [module.tenant_2_onprem_vpc.private_subnets[0]]
  security_group_ids  = [aws_security_group.tenant2_endpoint_sg.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "tenant2_ssm_messages_endpoint" {
  vpc_id              = module.tenant_2_onprem_vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [module.tenant_2_onprem_vpc.private_subnets[0]]
  security_group_ids  = [aws_security_group.tenant2_endpoint_sg.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "tenant2_ec2_messages_endpoint" {
  vpc_id              = module.tenant_2_onprem_vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [module.tenant_2_onprem_vpc.private_subnets[0]]
  security_group_ids  = [aws_security_group.tenant2_endpoint_sg.id]
  private_dns_enabled = true
}

resource "aws_instance" "tenant2_instance" {
  ami                         = data.aws_ami.amazon_linux_2.id
  subnet_id                   = module.tenant_2_onprem_vpc.private_subnets[0]
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.tenant2_instance_sg.id]
  associate_public_ip_address = false
  key_name                    = var.existing_key_name == null ? "${random_string.key_random_id.id}_key_pair" : var.existing_key_name
  iam_instance_profile        = var.existing_ssm_instance_profile == null && var.create_ssm_profile ? aws_iam_instance_profile.ssm_instance_profile[0].name : var.existing_ssm_instance_profile

  user_data = <<EOF
#!/bin/bash
sudo sed 's/PasswordAuthentication no/PasswordAuthentication yes/' -i /etc/ssh/sshd_config
sudo systemctl restart sshd
echo ec2-user:${var.vm_admin_password} | sudo chpasswd
EOF

  tags = {
    Name = "tenant2-instance"
  }
  #user_data = file("install-nginx.sh")

  depends_on = [aws_vpc_endpoint.tenant2_ssm_endpoint, aws_vpc_endpoint.tenant2_ssm_messages_endpoint, aws_vpc_endpoint.tenant2_ec2_messages_endpoint]
}