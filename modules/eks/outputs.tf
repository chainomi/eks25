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

# CloudWatch Alarms Outputs
output "cloudwatch_alarm_arns" {
  description = "Map of CloudWatch alarm ARNs by alarm type"
  value = var.cloudwatch_alarms.enabled ? {
    # Cluster-wide alarms (single alarm each)
    cpu_high                = length(aws_cloudwatch_metric_alarm.node_cpu_high) > 0 ? aws_cloudwatch_metric_alarm.node_cpu_high[0].arn : null
    memory_high             = length(aws_cloudwatch_metric_alarm.node_memory_high) > 0 ? aws_cloudwatch_metric_alarm.node_memory_high[0].arn : null
    disk_high               = length(aws_cloudwatch_metric_alarm.node_disk_high) > 0 ? aws_cloudwatch_metric_alarm.node_disk_high[0].arn : null
    network_transmit_errors = length(aws_cloudwatch_metric_alarm.node_network_transmit_errors) > 0 ? aws_cloudwatch_metric_alarm.node_network_transmit_errors[0].arn : null
    node_status_not_ready   = length(aws_cloudwatch_metric_alarm.node_status_not_ready) > 0 ? aws_cloudwatch_metric_alarm.node_status_not_ready[0].arn : null
    pod_count_high          = length(aws_cloudwatch_metric_alarm.pod_count_high) > 0 ? aws_cloudwatch_metric_alarm.pod_count_high[0].arn : null
    composite_critical      = length(aws_cloudwatch_composite_alarm.cluster_critical) > 0 ? aws_cloudwatch_composite_alarm.cluster_critical[0].arn : null

    # Per-node-group alarms (one per node group)
    node_count_low = {
      for ng_name, alarm in aws_cloudwatch_metric_alarm.node_count_low : ng_name => alarm.arn
    }
  } : {
    # Empty structure matching the enabled case
    cpu_high                = null
    memory_high             = null
    disk_high               = null
    network_transmit_errors = null
    node_status_not_ready   = null
    pod_count_high          = null
    composite_critical      = null
    node_count_low          = {}
  }
}

output "cloudwatch_alarm_names" {
  description = "List of all CloudWatch alarm names created"
  value = var.cloudwatch_alarms.enabled ? concat(
    # Cluster-wide alarm names
    length(aws_cloudwatch_metric_alarm.node_cpu_high) > 0 ? [aws_cloudwatch_metric_alarm.node_cpu_high[0].alarm_name] : [],
    length(aws_cloudwatch_metric_alarm.node_memory_high) > 0 ? [aws_cloudwatch_metric_alarm.node_memory_high[0].alarm_name] : [],
    length(aws_cloudwatch_metric_alarm.node_disk_high) > 0 ? [aws_cloudwatch_metric_alarm.node_disk_high[0].alarm_name] : [],
    length(aws_cloudwatch_metric_alarm.node_network_transmit_errors) > 0 ? [aws_cloudwatch_metric_alarm.node_network_transmit_errors[0].alarm_name] : [],
    length(aws_cloudwatch_metric_alarm.node_status_not_ready) > 0 ? [aws_cloudwatch_metric_alarm.node_status_not_ready[0].alarm_name] : [],
    length(aws_cloudwatch_metric_alarm.pod_count_high) > 0 ? [aws_cloudwatch_metric_alarm.pod_count_high[0].alarm_name] : [],
    length(aws_cloudwatch_composite_alarm.cluster_critical) > 0 ? [aws_cloudwatch_composite_alarm.cluster_critical[0].alarm_name] : [],
    # Per-node-group alarm names
    [for alarm in aws_cloudwatch_metric_alarm.node_count_low : alarm.alarm_name]
  ) : []
}

