output "public_ip" {
  description = "Public IP of the EC2 instance"
  value       = module.ec2.public_ip
}

output "domain_name" {
  description = "Domain name for the site"
  value       = var.domain_name
}

output "nameservers" {
  description = "Route 53 nameservers (auto-applied to registered domain)"
  value       = module.dns.nameservers
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ec2-user@${module.ec2.public_ip}"
}

output "ecr_repository_urls" {
  description = "ECR repository URLs for each container image"
  value       = module.ecr.repository_urls
}

output "instance_id" {
  description = "EC2 instance ID (used by ssh-toggle script)"
  value       = module.ec2.instance_id
}

output "ssh_security_group_id" {
  description = "SSH security group ID (used by ssh-toggle script)"
  value       = module.ec2.ssh_security_group_id
}
