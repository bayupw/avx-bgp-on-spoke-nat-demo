resource "random_string" "key_random_id" {
  length  = 3
  special = false
  upper   = false
}

resource "tls_private_key" "new_private_key" {
  algorithm = "RSA"
}

resource "local_file" "new_private_key" {
  content         = tls_private_key.new_private_key.private_key_pem
  filename        = "${random_string.key_random_id.id}-key.pem"
  file_permission = "0600"
}

resource "aws_key_pair" "new_key_pair" {
  key_name   = "${random_string.key_random_id.id}_key_pair"
  public_key = tls_private_key.new_private_key.public_key_openssh
}