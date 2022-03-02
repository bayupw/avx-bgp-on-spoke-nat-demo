# ---------------------------------------------------------------------------------------------------------------------
# Transit
# ---------------------------------------------------------------------------------------------------------------------

# Transit VPC and Transit Gateways
module "aws_transit_1" {
  source              = "terraform-aviatrix-modules/mc-transit/aviatrix"
  cloud               = "aws"
  name                = "transit"
  region              = var.aws_region
  cidr                = cidrsubnet(var.cloud_supernet, 15, 25) # "10.0.50.0/23"
  account             = var.aws_account
  insane_mode         = var.hpe
  instance_size       = var.aws_instance_size
  ha_gw               = var.ha_gw
  enable_segmentation = var.enable_segmentation
  local_as_number     = 65000
}

# Shared-Services Segmentation Security Domain
resource "aviatrix_segmentation_security_domain" "sharedservices_segmentation_security_domain" {
  domain_name = "Shared-Services"
}

# Tenant 1 Segmentation Security Domain
resource "aviatrix_segmentation_security_domain" "tenant1_segmentation_security_domain" {
  domain_name = "Tenant-1"
}

# Tenant 2 Segmentation Security Domain
resource "aviatrix_segmentation_security_domain" "tenant2_segmentation_security_domain" {
  domain_name = "Tenant-2"
}

# Tenant 1 to Shared Services
resource "aviatrix_segmentation_security_domain_connection_policy" "tenant1_to_sharedservices" {
  domain_name_1 = aviatrix_segmentation_security_domain.tenant1_segmentation_security_domain.domain_name
  domain_name_2 = aviatrix_segmentation_security_domain.sharedservices_segmentation_security_domain.domain_name
}

# Tenant 2 to Shared Services
resource "aviatrix_segmentation_security_domain_connection_policy" "tenant2_to_sharedservices" {
  domain_name_1 = aviatrix_segmentation_security_domain.tenant2_segmentation_security_domain.domain_name
  domain_name_2 = aviatrix_segmentation_security_domain.sharedservices_segmentation_security_domain.domain_name
}