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
  description = "AMI ID for the web EC2. Pinned to avoid surprise replacements when AWS publishes new Amazon Linux releases. Rotating this value will destroy the instance and its root EBS, which holds the MySQL Docker volume — plan a data migration before bumping."
  type        = string
  default     = "ami-0fc6cf99992956a4a"
}
