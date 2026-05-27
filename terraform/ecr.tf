locals {
  ecr_repositories = toset([
    "config-server",
    "discovery-server",
    "api-gateway",
    "customers-service",
    "vets-service",
    "visits-service",
    "genai-service",
    "admin-server",
  ])
}

resource "aws_ecr_repository" "services" {
  for_each = local.ecr_repositories

  name                 = "foster-petclinic/${each.key}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "foster-petclinic-${each.key}"
  }
}

# Lifecycle policy: keep the 10 most recent images per repository,
# removing untagged images after 1 day.
resource "aws_ecr_lifecycle_policy" "services" {
  for_each   = aws_ecr_repository.services
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Remove untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep last 10 images (any tag status)"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = { type = "expire" }
      }
    ]
  })
}
