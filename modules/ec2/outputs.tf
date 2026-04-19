output "public_ip" {
  value = aws_eip.web.public_ip
}

output "instance_id" {
  value = aws_instance.web.id
}

output "ssh_security_group_id" {
  value = aws_security_group.ssh.id
}

output "data_volume_id" {
  value       = aws_ebs_volume.data.id
  description = "Persistent data EBS volume ID. Snapshot this before risky operations."
}
