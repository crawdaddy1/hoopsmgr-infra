variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "key_name" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "ec2_ami_id" {
  description = "AMI ID for the web EC2. Set at the root level; see variables.tf at repo root for the pinning rationale and rotation flow."
  type        = string
}

variable "data_volume_size_gb" {
  description = "Size of the persistent data EBS volume (MySQL + Let's Encrypt + media). gp3 pricing is ~$0.08/GB-month."
  type        = number
  default     = 10
}
