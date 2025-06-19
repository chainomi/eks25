output "aws_account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "region" {
  value = local.region
}

output "cluster_name" {
  value = "${local.environment}-${local.application_name}"
}

output "ecr_repo_map" {
  value = module.ecr.repository_url_map
}