# CloudWatch Alarms for EKS Node Groups

# Local variables for alarm configuration
locals {
  alarm_enabled     = var.cloudwatch_alarms.enabled
  alarm_sns_topic   = var.cloudwatch_alarms.sns_topic_arn
  alarm_actions     = local.alarm_enabled && local.alarm_sns_topic != null ? [local.alarm_sns_topic] : []
  ok_actions        = local.alarm_enabled && local.alarm_sns_topic != null ? [local.alarm_sns_topic] : []

  # Create a map of node group names for easier iteration
  node_group_names = keys(var.managed_node_groups)

  # Map of node group names to their ASG names from EKS module outputs
  node_group_asgs = {
    for ng_name in local.node_group_names :
    ng_name => try(module.eks.eks_managed_node_groups[ng_name].node_group_autoscaling_group_names[0], null)
  }

  # Alarm configuration with defaults using try() for safe access
  cpu_config = {
    threshold          = try(var.cloudwatch_alarms.cpu.threshold, 80)
    period             = try(var.cloudwatch_alarms.cpu.period, 300)
    evaluation_periods = try(var.cloudwatch_alarms.cpu.evaluation_periods, 2)
  }

  memory_config = {
    threshold          = try(var.cloudwatch_alarms.memory.threshold, 80)
    period             = try(var.cloudwatch_alarms.memory.period, 300)
    evaluation_periods = try(var.cloudwatch_alarms.memory.evaluation_periods, 2)
  }

  disk_config = {
    threshold          = try(var.cloudwatch_alarms.disk.threshold, 85)
    period             = try(var.cloudwatch_alarms.disk.period, 300)
    evaluation_periods = try(var.cloudwatch_alarms.disk.evaluation_periods, 2)
  }

  node_count_config = {
    period             = try(var.cloudwatch_alarms.node_count.period, 300)
    evaluation_periods = try(var.cloudwatch_alarms.node_count.evaluation_periods, 2)
  }

  network_config = {
    errors_threshold   = try(var.cloudwatch_alarms.network.errors_threshold, 10)
    period             = try(var.cloudwatch_alarms.network.period, 300)
    evaluation_periods = try(var.cloudwatch_alarms.network.evaluation_periods, 2)
  }

  node_status_config = {
    period             = try(var.cloudwatch_alarms.node_status.period, 300)
    evaluation_periods = try(var.cloudwatch_alarms.node_status.evaluation_periods, 2)
  }

  pod_count_config = {
    threshold          = try(var.cloudwatch_alarms.pod_count.threshold, 100)
    period             = try(var.cloudwatch_alarms.pod_count.period, 300)
    evaluation_periods = try(var.cloudwatch_alarms.pod_count.evaluation_periods, 2)
  }
}

# Node CPU Utilization Alarm (Cluster-wide)
resource "aws_cloudwatch_metric_alarm" "node_cpu_high" {
  count = local.alarm_enabled ? 1 : 0

  alarm_name          = "${var.cluster_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = local.cpu_config.evaluation_periods
  metric_name         = "node_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = local.cpu_config.period
  statistic           = "Average"
  threshold           = local.cpu_config.threshold
  alarm_description   = "Alert when CPU utilization is high for cluster ${var.cluster_name}"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
}

# Node Memory Utilization Alarm (Cluster-wide)
resource "aws_cloudwatch_metric_alarm" "node_memory_high" {
  count = local.alarm_enabled ? 1 : 0

  alarm_name          = "${var.cluster_name}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = local.memory_config.evaluation_periods
  metric_name         = "node_memory_utilization"
  namespace           = "ContainerInsights"
  period              = local.memory_config.period
  statistic           = "Average"
  threshold           = local.memory_config.threshold
  alarm_description   = "Alert when memory utilization is high for cluster ${var.cluster_name}"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
}

# Node Disk Utilization Alarm (Cluster-wide)
resource "aws_cloudwatch_metric_alarm" "node_disk_high" {
  count = local.alarm_enabled ? 1 : 0

  alarm_name          = "${var.cluster_name}-disk-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = local.disk_config.evaluation_periods
  metric_name         = "node_filesystem_utilization"
  namespace           = "ContainerInsights"
  period              = local.disk_config.period
  statistic           = "Average"
  threshold           = local.disk_config.threshold
  alarm_description   = "Alert when disk utilization is high for cluster ${var.cluster_name}"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
}

# Node Count Alarms - Alert when node count is below minimum for each node group
resource "aws_cloudwatch_metric_alarm" "node_count_low" {
  for_each = local.alarm_enabled ? toset(local.node_group_names) : []

  alarm_name          = "${var.cluster_name}-${each.key}-node-count-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = local.node_count_config.evaluation_periods
  metric_name         = "GroupInServiceInstances"
  namespace           = "AWS/AutoScaling"
  period              = local.node_count_config.period
  statistic           = "Average"
  threshold           = lookup(var.managed_node_groups[each.key], "min_size", 1)
  alarm_description   = "Alert when node count is below minimum (${lookup(var.managed_node_groups[each.key], "min_size", 1)}) for node group ${each.key}"
  treat_missing_data  = "notBreaching"

  dimensions = {
    AutoScalingGroupName = local.node_group_asgs[each.key] != null ? local.node_group_asgs[each.key] : "ASG-NOT-FOUND-${each.key}"
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
}

# Node Network Transmit Errors (Cluster-wide)
resource "aws_cloudwatch_metric_alarm" "node_network_transmit_errors" {
  count = local.alarm_enabled ? 1 : 0

  alarm_name          = "${var.cluster_name}-network-transmit-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = local.network_config.evaluation_periods
  metric_name         = "node_network_tx_errors"
  namespace           = "ContainerInsights"
  period              = local.network_config.period
  statistic           = "Sum"
  threshold           = local.network_config.errors_threshold
  alarm_description   = "Alert when network transmit errors are high for cluster ${var.cluster_name}"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
}

# Node Status - Alert when nodes are in NotReady state (Cluster-wide)
resource "aws_cloudwatch_metric_alarm" "node_status_not_ready" {
  count = local.alarm_enabled ? 1 : 0

  alarm_name          = "${var.cluster_name}-node-not-ready"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = local.node_status_config.evaluation_periods
  metric_name         = "cluster_failed_node_count"
  namespace           = "ContainerInsights"
  period              = local.node_status_config.period
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "Alert when nodes are in NotReady state for cluster ${var.cluster_name}"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
}

# Pod Count High - Alert when pod count is near node capacity (Cluster-wide)
resource "aws_cloudwatch_metric_alarm" "pod_count_high" {
  count = local.alarm_enabled ? 1 : 0

  alarm_name          = "${var.cluster_name}-pod-count-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = local.pod_count_config.evaluation_periods
  metric_name         = "node_number_of_running_pods"
  namespace           = "ContainerInsights"
  period              = local.pod_count_config.period
  statistic           = "Average"
  threshold           = local.pod_count_config.threshold
  alarm_description   = "Alert when pod count is high for cluster ${var.cluster_name}"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
  }

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
}

# Composite Alarm - Critical Cluster Health
resource "aws_cloudwatch_composite_alarm" "cluster_critical" {
  count = local.alarm_enabled ? 1 : 0

  alarm_name          = "${var.cluster_name}-critical-health"
  alarm_description   = "Composite alarm for critical health issues in cluster ${var.cluster_name}"
  actions_enabled     = true
  alarm_actions       = local.alarm_actions
  ok_actions          = local.ok_actions

  alarm_rule = format(
    "ALARM(%s) OR ALARM(%s) OR ALARM(%s)",
    aws_cloudwatch_metric_alarm.node_cpu_high[0].alarm_name,
    aws_cloudwatch_metric_alarm.node_memory_high[0].alarm_name,
    aws_cloudwatch_metric_alarm.node_status_not_ready[0].alarm_name
  )
}
