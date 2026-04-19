variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "hoopsmgr"
}

variable "instance_type" {
  description = "EC2 instance type (t3.micro is free tier eligible)"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of the SSH key pair to use for EC2 access"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the site"
  type        = string
  default     = "hoopsmanager.com"
}

variable "grafana_url" {
  description = "Grafana Cloud stack URL"
  type        = string
  default     = "https://hoopmgr.grafana.net"
}

variable "notification_email" {
  description = "Email for Grafana alert notifications"
  type        = string
  default     = "crawdaddy115@gmail.com"
}
