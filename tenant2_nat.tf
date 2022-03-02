# ---------------------------------------------------------------------------------------------------------------------
# Tenant 2 NAT Sections
# ---------------------------------------------------------------------------------------------------------------------

# On-Prem to Shared Services SNAT
# Enable NAT function of mode "customized_snat" for an Aviatrix AWS Spoke Gateway
# Customized SNAT
# Source CIDR Tenant On-Prem 192.168.200.0/25
# Destination CIDR Shared Services 10.0.100.0/24
# Connection = Transit-GW
# SNAT IP Spoke GW = Spoke-2-GW Private IP
resource "aviatrix_gateway_snat" "aws_tenant_2_snatgw" {
  gw_name   = module.aws_tenant_2.spoke_gateway.gw_name
  snat_mode = "customized_snat"
  snat_policy {
    src_cidr   = var.tenant_cidr
    dst_cidr   = module.aws_shared_services.vpc.cidr # "10.0.100.0/24"
    protocol   = "all"
    connection = module.aws_transit_1.transit_gateway.gw_name
    snat_ips   = module.aws_tenant_2.spoke_gateway.private_ip
  }
  snat_policy {
    protocol   = "all"
    connection = "Tenant2-On-Prem_to_Landing-Tenant2-Spoke-1@site2cloud"
    mark       = "10210"
    snat_ips   = module.aws_tenant_2.spoke_gateway.private_ip
  }
  depends_on = [module.aws_tenant_2, module.tenant_2_onprem]
}

# On-Prem to Shared Services HA SNAT
# Enable NAT function of mode "customized_snat" for an Aviatrix AWS Spoke Gateway
# Customized SNAT
# SRC CIDR - Tenant-1 On-Prem: 192.168.200.0/25
# DST CIDR - Shared Services: 10.0.100.0/24
# Connection = Transit-GW
# SNAT IP Spoke HAGW = Spoke-2-HAGW Private IP
resource "aviatrix_gateway_snat" "aws_tenant_2_snathagw" {
  gw_name   = module.aws_tenant_2.spoke_gateway.ha_gw_name
  snat_mode = "customized_snat"
  snat_policy {
    src_cidr   = var.tenant_cidr
    dst_cidr   = module.aws_shared_services.vpc.cidr # "10.0.100.0/24"
    protocol   = "all"
    connection = module.aws_transit_1.transit_gateway.gw_name
    snat_ips   = module.aws_tenant_2.spoke_gateway.ha_private_ip
  }
  snat_policy {
    protocol   = "all"
    connection = "Tenant2-On-Prem_to_Landing-Tenant2-Spoke-1@site2cloud"
    mark       = "10210"
    snat_ips   = module.aws_tenant_2.spoke_gateway.ha_private_ip
  }
  depends_on = [module.aws_tenant_2, module.tenant_2_onprem, aviatrix_gateway_snat.aws_tenant_2_snatgw]
}

# Cloud to On-Prem DNAT
# Add policy for destination NAT function for an Aviatrix AWS Spoke Gateway
# DNAT
# SRC CIDR - Shared Services: 10.0.100.0/24
# DST CIDR - Tenant-2 On-Prem Virtual CIDR Host /32
resource "aviatrix_gateway_dnat" "aws_tenant_2_dnatgw" {
  gw_name = module.aws_tenant_2.spoke_gateway.gw_name
  dnat_policy {
    src_cidr   = module.aws_shared_services.vpc.cidr
    dst_cidr   = var.tenant_2_virtual_host # Virtual CIDR Host /32
    protocol   = "all"
    connection = module.aws_transit_1.transit_gateway.gw_name
    mark       = "10210"                                      # Virtual Host 101.10
    dnat_ips   = module.tenant_2_onprem_private_vm.private_ip # Real Host IP
  }
  depends_on = [module.aws_tenant_2, module.tenant_2_onprem]
}