# ---------------------------------------------------------------------------------------------------------------------
# CIDR
# ---------------------------------------------------------------------------------------------------------------------
variable "cloud_supernet" {
  type    = string
  default = "10.0.0.0/8"
}

variable "tenant_cidr" {
  type    = string
  default = "192.168.200.0/24"
}

variable "tenant_2_virtual_host" {
  type    = string
  default = "192.168.102.10/32"
}

# ---------------------------------------------------------------------------------------------------------------------
# CSP Accounts
# ---------------------------------------------------------------------------------------------------------------------
variable "aws_account" {
  type        = string
  description = "AWS access account"
}

# ---------------------------------------------------------------------------------------------------------------------
# CSP Regions
# ---------------------------------------------------------------------------------------------------------------------
variable "aws_region" {
  type        = string
  default     = "ap-southeast-2"
  description = "AWS region"
}

# ---------------------------------------------------------------------------------------------------------------------
# Aviatrix Transit & Spoke Gateway
# ---------------------------------------------------------------------------------------------------------------------
variable "aws_instance_size" {
  type        = string
  default     = "t2.micro" #hpe "c5.xlarge"
  description = "AWS gateway instance size"
}

variable "aws_transit_1_gw_name" {
  type        = string
  default     = "aws-transit-1"
  description = "AWS Aviatrix transit gateway name"
}

# ---------------------------------------------------------------------------------------------------------------------
# Aviatrix Gateway Options
# ---------------------------------------------------------------------------------------------------------------------
variable "hpe" {
  type        = bool
  default     = false
  description = "Insane mode"
}

variable "ha_gw" {
  type        = bool
  default     = true
  description = "Enable HA gateway"
}

variable "enable_segmentation" {
  type        = bool
  default     = true
  description = "Enable segmentation"
}

# ---------------------------------------------------------------------------------------------------------------------
# AWS EC2 VM Options
# ---------------------------------------------------------------------------------------------------------------------
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  name_regex  = "amzn2-ami-hvm*"
}

variable "vm_admin_password" {
  type        = string
  default     = "Aviatrix123#"
  description = "VM admin password"
}

variable "existing_key_name" {
  type        = string
  default     = null
  description = "Existing EC2 keypair name"
}

variable "create_ssm_profile" {
  type        = bool
  default     = true
  description = "Create SSM Profile"
}

variable "existing_ssm_instance_profile" {
  type        = string
  default     = null
  description = "Existing SSM Profile"
}

# Learn my public IP
data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

variable "ingress_cidr_blocks" {
  type        = bool
  default     = null
  description = "Ingress CIDR blocks"
}