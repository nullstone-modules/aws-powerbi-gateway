output "region" {
  value       = data.aws_region.this.region
  description = "string ||| The AWS region where the gateway instance resides."
}

output "instance_id" {
  value       = aws_instance.this.id
  description = "string ||| The Instance ID of the EC2 instance running the gateway."
}

output "private_urls" {
  value       = local.private_urls
  description = "list(string) ||| A list of URLs only accessible inside the network"
}

output "public_urls" {
  value       = local.public_urls
  description = "list(string) ||| A list of URLs accessible to the public"
}

output "private_ip" {
  value       = aws_instance.this.private_ip
  description = "string ||| The private IP of the gateway instance."
}

output "security_group_id" {
  value       = aws_security_group.this.id
  description = "string ||| The ID of the security group attached to the gateway instance."
}

output "gateway_name" {
  value       = local.gateway_name
  description = "string ||| The name of the gateway cluster registered with the Power BI service."
}

output "admin_username" {
  value       = "Administrator"
  description = "string ||| The Windows administrator username for RDP access."
}

output "admin_password" {
  value       = rsadecrypt(aws_instance.this.password_data, tls_private_key.this.private_key_pem)
  description = "string ||| The Windows administrator password for RDP access (via SSM port forwarding)."
  sensitive   = true
}
