resource "random_string" "key_random_id" {
  count   = var.existing_key_name == null ? 1 : 0
  length  = 3
  special = false
  upper   = false
}

resource "tls_private_key" "new_private_key" {
  count     = var.existing_key_name == null ? 1 : 0
  algorithm = "RSA"
}

resource "local_file" "new_private_key" {
  count           = var.existing_key_name == null ? 1 : 0
  content         = tls_private_key.new_private_key[0].private_key_pem
  filename        = "${random_string.key_random_id[0].id}-key.pem"
  file_permission = "0600"
}

resource "aws_key_pair" "new_key_pair" {
  count      = var.existing_key_name == null ? 1 : 0
  key_name   = "${random_string.key_random_id[0].id}_key_pair"
  public_key = tls_private_key.new_private_key[0].public_key_openssh
}