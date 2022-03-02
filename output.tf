output "sharedservices_instance_private_ip" {
  value = aws_instance.sharedservices_instance.private_ip
}

output "tenant1_instance_private_ip" {
  value = aws_instance.tenant1_instance.private_ip
}

output "tenant2_instance_private_ip" {
  value = aws_instance.tenant2_instance.private_ip
}

output "tenant2_instance_private_virtual_ip" {
  value = var.tenant_2_virtual_host
}