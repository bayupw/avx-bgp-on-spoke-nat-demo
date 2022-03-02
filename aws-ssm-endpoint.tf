# ---------------------------------------------------------------------------------------------------------------------
# AWS SSM
# ---------------------------------------------------------------------------------------------------------------------
resource "random_string" "ssm_random_id" {
  count   = var.create_ssm_profile && var.existing_ssm_instance_profile == null ? 1 : 0
  length  = 3
  special = false
  upper   = false
}

resource "aws_iam_role" "ssm_instance_role" {
  count              = var.create_ssm_profile && var.existing_ssm_instance_profile == null ? 1 : 0
  name               = "ssm-instance-role-${random_string.ssm_random_id[0].id}"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": {
    "Effect": "Allow",
    "Principal": {"Service": "ec2.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }
}
EOF
}

resource "aws_iam_role_policy_attachment" "ssm_instance_role_policy_attachment" {
  count      = var.create_ssm_profile && var.existing_ssm_instance_profile == null ? 1 : 0
  role       = aws_iam_role.ssm_instance_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_instance_profile" {
  count = var.create_ssm_profile && var.existing_ssm_instance_profile == null ? 1 : 0
  name  = "ssm-instance-profile-${random_string.ssm_random_id[0].id}"
  role  = aws_iam_role.ssm_instance_role[0].name
}