output "nameservers" {
  description = "Nameservers to set at your domain registrar"
  value       = aws_route53_zone.main.name_servers
}

output "zone_id" {
  value = aws_route53_zone.main.zone_id
}
