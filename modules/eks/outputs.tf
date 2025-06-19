output "cluster_id" {
  description = "EKS cluster ID."
  value       = module.eks.cluster_id
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane."
  value       = module.eks.cluster_endpoint
}

output "cluster_primary_security_group_id" {
  description = "Security group ids attached to the cluster control plane."
  value       = module.eks.cluster_primary_security_group_id
}

# output "config_map_aws_auth" {
#   description = "A kubernetes configuration to authenticate to this EKS cluster."
#   value       = module.eks.aws_auth_configmap_yaml
# }

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = var.cluster_name
}

output "oidc_arn" {
  description = "Kubernetes OIDC arn"
  value       = module.eks.oidc_provider_arn
}

output "oidc_issuer_url" {
  description = "Kubernetes OIDC url"
  value       = module.eks.cluster_oidc_issuer_url
}

output "node_security_group_id" {
  description = "node group security group id"
  value       = module.eks.node_security_group_id
}

output "vpc_id" {
  description = "vpc id from vpc module"
  value       = module.vpc.vpc_id
}


