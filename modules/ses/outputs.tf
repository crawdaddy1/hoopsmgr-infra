output "domain_identity_arn" {
  description = "ARN of the SES domain identity"
  value       = aws_ses_domain_identity.main.arn
}

output "verification_status" {
  description = "Whether the SES domain is verified"
  value       = "Check AWS console — verification depends on DNS propagation"
}
