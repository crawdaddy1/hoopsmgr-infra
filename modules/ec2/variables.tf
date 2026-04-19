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
  description = "AMI ID for the web EC2. Pinned to avoid surprise replacements when AWS publishes new Amazon Linux releases. Persistent data lives on aws_ebs_volume.data, so rotating this value safely replaces the instance without losing MySQL / certs / media."
  type        = string
  default     = "ami-0fc6cf99992956a4a"
}

variable "data_volume_size_gb" {
  description = "Size of the persistent data EBS volume (MySQL + Let's Encrypt + media). gp3 pricing is ~$0.08/GB-month."
  type        = number
  default     = 10
}
