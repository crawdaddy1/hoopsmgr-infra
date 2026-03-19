variable "domain_name" {
  description = "Domain name for SES identity"
  type        = string
}

variable "zone_id" {
  description = "Route 53 hosted zone ID for DNS verification records"
  type        = string
}
