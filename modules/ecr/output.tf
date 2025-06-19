output "repository_url_map" {
  description = "List of ECR repos"
  value       = values(aws_ecr_repository.ecr)[*].repository_url
}