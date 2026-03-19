# ECR repositories for each container
resource "aws_ecr_repository" "repos" {
  for_each = toset(var.repo_names)

  name                 = "${var.project_name}/${each.value}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = false  # Skip scanning to stay free
  }

  tags = {
    Name = "${var.project_name}-${each.value}"
  }
}

# Lifecycle policy - keep only last 3 images per repo to control storage costs
resource "aws_ecr_lifecycle_policy" "cleanup" {
  for_each   = aws_ecr_repository.repos
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only last 3 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 3
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
