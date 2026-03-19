variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "repo_names" {
  description = "List of ECR repository names"
  type        = list(string)
  default     = ["web", "react", "bbref"]
}
