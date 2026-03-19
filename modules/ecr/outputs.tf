output "repository_urls" {
  description = "Map of repo name to ECR URL"
  value       = { for k, v in aws_ecr_repository.repos : k => v.repository_url }
}

output "registry_id" {
  description = "ECR registry ID (AWS account ID)"
  value       = values(aws_ecr_repository.repos)[0].registry_id
}
