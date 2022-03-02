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

  depends_on = [module.aws_transit_1, module.tenant_1_onprem]

  ###############################
  # BGP Route Approval Sections #
  ###############################
  enable_learned_cidrs_approval = true
  approved_learned_cidrs        = [cidrsubnet(var.tenant_cidr, 4, 2), cidrsubnet(var.tenant_cidr, 4, 3)]
  # spoke_bgp_manual_advertise_cidrs = ["10.0.102.0/24,10.0.100.0/24"]   # Advertise Spoke VPC and Shared Services VPC
}

# Tenant-2 On-Prem - Overlaps with Tenant-1 On-Prem
module "tenant_2_onprem" {
  source          = "github.com/bayupw/avx-bgp-on-spoke-s2c"
  hostname        = "Tenant2-On-Prem"
  tunnel_proto    = "IPsec"
  network_cidr    = var.tenant_cidr
  public_subnets  = [cidrsubnet(var.tenant_cidr, 4, 3)] # 192.168.200.48/28
  private_subnets = [cidrsubnet(var.tenant_cidr, 4, 2)] # 192.168.200.32/28
  instance_type   = "t3.medium"
  public_conns    = ["${module.aws_tenant_2.spoke_gateway.gw_name}:${module.aws_tenant_2.spoke_gateway.local_as_number}:1"]
  csr_bgp_as_num  = "65012"
  create_client   = false
  #key_name        = var.key_name
  depends_on      = [module.tenant_1_onprem, module.aws_tenant_2]
}

# Tenant-2 On-Prem Public IP VM
module "tenant_2_onprem_public_vm" {
  source                      = "github.com/bayupw/aws-ubuntu-wpassword"
  vpc_name                    = "Tenant2-On-Prem"
  vpc_subnet                  = "Tenant2-On-Prem Public Subnet 1"
  key_name                    = var.key_name
  instance_name               = "Tenant2-On-Prem-Public-1"
  ingress_cidr_blocks         = var.ingress_cidr_blocks == null ? "${chomp(data.http.myip.body)}/32" : var.ingress_cidr_blocks
  associate_public_ip_address = true
  depends_on                  = [module.tenant_2_onprem, module.tenant_1_onprem, module.aws_tenant_2]
}

# Tenant-2 On-Prem Private IP VM
module "tenant_2_onprem_private_vm" {
  source                      = "github.com/bayupw/aws-ubuntu-wpassword"
  vpc_name                    = "Tenant2-On-Prem"
  vpc_subnet                  = "Tenant2-On-Prem Private Subnet 1"
  key_name                    = var.existing_key_name == null ? "${random_string.key_random_id[0].id}_key_pair" : var.existing_key_name
  instance_name               = "Tenant2-On-Prem-Private-1"
  associate_public_ip_address = false
  depends_on                  = [module.tenant_2_onprem, module.tenant_1_onprem, module.aws_tenant_2]
}