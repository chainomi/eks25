# CloudWatch Alarms for EKS Node Groups

This module includes comprehensive CloudWatch alarms for monitoring EKS node groups. The alarms are automatically created for each managed node group in your cluster.

## Features

The CloudWatch alarms monitor the following metrics for each node group:

### 1. **CPU Utilization** (`node_cpu_high`)
- Alerts when average CPU utilization exceeds threshold
- Default: 80% for 2 consecutive 5-minute periods
- Helps identify compute capacity issues

### 2. **Memory Utilization** (`node_memory_high`)
- Alerts when average memory utilization exceeds threshold
- Default: 80% for 2 consecutive 5-minute periods
- Helps identify memory pressure

### 3. **Disk Utilization** (`node_disk_high`)
- Alerts when disk utilization exceeds threshold
- Default: 85% for 2 consecutive 5-minute periods
- Prevents disk space exhaustion

### 4. **Node Count** (`node_count_low`)
- Alerts when node count drops to or below minimum
- Helps identify node termination or scaling issues
- Threshold dynamically set to node group's `min_size`

### 5. **Network Transmit Errors** (`node_network_transmit_errors`)
- Alerts when network transmit errors exceed threshold
- Default: More than 10 errors over 5 minutes
- Helps identify network issues

### 6. **Node Status** (`node_status_not_ready`)
- Alerts when nodes enter NotReady state
- Immediate notification of node health issues
- Critical for maintaining cluster capacity

### 7. **Pod Count** (`pod_count_high`)
- Alerts when pod count per node is high
- Default: More than 100 pods per node
- Helps identify pod scheduling issues

### 8. **Composite Alarm** (`node_group_critical`)
- Combines CPU, Memory, and Node Status alarms
- Single alarm for critical node group health
- Reduces alert fatigue

## Usage

### Basic Usage (Default Settings)

CloudWatch alarms are enabled by default with sensible thresholds:

```hcl
module "eks" {
  source = "./modules/eks"

  # ... other configuration ...

  # Alarms are enabled by default with standard thresholds
  # No additional configuration needed
}
```

### With SNS Notifications

Add SNS topic for alarm notifications:

```hcl
resource "aws_sns_topic" "eks_alerts" {
  name = "${var.cluster_name}-eks-alerts"
}

resource "aws_sns_topic_subscription" "eks_alerts_email" {
  topic_arn = aws_sns_topic.eks_alerts.arn
  protocol  = "email"
  endpoint  = "devops-team@example.com"
}

module "eks" {
  source = "./modules/eks"

  # ... other configuration ...

  cloudwatch_alarms = {
    enabled       = true
    sns_topic_arn = aws_sns_topic.eks_alerts.arn
  }
}
```

### Custom Thresholds

Override specific alarm thresholds:

```hcl
module "eks" {
  source = "./modules/eks"

  # ... other configuration ...

  cloudwatch_alarms = {
    enabled       = true
    sns_topic_arn = aws_sns_topic.eks_alerts.arn

    # CPU Alarms - Alert at 90% instead of 80%
    cpu = {
      threshold          = 90
      period             = 600  # 10-minute periods
      evaluation_periods = 3
    }

    # Memory Alarms
    memory = {
      threshold = 85
    }

    # Disk Alarms - More headroom
    disk = {
      threshold = 90
    }

    # Network Alarms - Higher tolerance
    network = {
      errors_threshold = 50
    }

    # Pod Count - Adjust for your instance size
    pod_count = {
      threshold = 80  # Alert when >80 pods per node
    }
  }
}
```

### Minimal Configuration (Just Change Thresholds)

Only override what you need, everything else uses defaults:

```hcl
module "eks" {
  source = "./modules/eks"

  # ... other configuration ...

  cloudwatch_alarms = {
    cpu = {
      threshold = 90  # Only change CPU threshold, everything else is default
    }
  }
}
```

### Disable Alarms

To disable all CloudWatch alarms:

```hcl
module "eks" {
  source = "./modules/eks"

  # ... other configuration ...

  cloudwatch_alarms = {
    enabled = false
  }
}
```

## Configuration Variable

All CloudWatch alarm settings are configured through a single `cloudwatch_alarms` object variable:

```hcl
variable "cloudwatch_alarms" {
  type = object({
    enabled         = optional(bool, true)
    sns_topic_arn   = optional(string, null)

    cpu = optional(object({
      threshold           = optional(number, 80)
      period              = optional(number, 300)
      evaluation_periods  = optional(number, 2)
    }), {})

    memory = optional(object({
      threshold           = optional(number, 80)
      period              = optional(number, 300)
      evaluation_periods  = optional(number, 2)
    }), {})

    disk = optional(object({
      threshold           = optional(number, 85)
      period              = optional(number, 300)
      evaluation_periods  = optional(number, 2)
    }), {})

    node_count = optional(object({
      period              = optional(number, 300)
      evaluation_periods  = optional(number, 2)
    }), {})

    network = optional(object({
      errors_threshold    = optional(number, 10)
      period              = optional(number, 300)
      evaluation_periods  = optional(number, 2)
    }), {})

    node_status = optional(object({
      period              = optional(number, 300)
      evaluation_periods  = optional(number, 2)
    }), {})

    pod_count = optional(object({
      threshold           = optional(number, 100)
      period              = optional(number, 300)
      evaluation_periods  = optional(number, 2)
    }), {})
  })
}
```

### Default Values Summary

| Alarm Type | Threshold | Period (seconds) | Evaluation Periods | Description |
|------------|-----------|------------------|-------------------|-------------|
| **CPU** | 80% | 300 | 2 | Alert when CPU >80% for 10 minutes |
| **Memory** | 80% | 300 | 2 | Alert when memory >80% for 10 minutes |
| **Disk** | 85% | 300 | 2 | Alert when disk >85% for 10 minutes |
| **Node Count** | min_size | 300 | 2 | Alert when nodes ≤ min_size |
| **Network** | 10 errors | 300 | 2 | Alert when >10 network errors |
| **Node Status** | 0 failed | 300 | 2 | Alert when any node NotReady |
| **Pod Count** | 100 pods | 300 | 2 | Alert when >100 pods per node |

## Outputs

The module provides outputs for referencing the created alarms:

```hcl
# Access alarm ARNs by type and node group
output "cpu_alarms" {
  value = module.eks.cloudwatch_alarm_arns.cpu_high
}

# List all alarm names
output "all_alarm_names" {
  value = module.eks.cloudwatch_alarm_names
}
```

## Alarm Naming Convention

Alarms follow this naming pattern:
```
{cluster_name}-{node_group_name}-{alarm_type}
```

Examples:
- `development-eks-core-node-group-cpu-high`
- `production-eks-workers-memory-high`
- `staging-eks-spot-disk-high`

## Prerequisites

1. **CloudWatch Container Insights** must be enabled (already configured in this module via `enable_aws_cloudwatch_metrics = true`)
2. **Node groups** must be defined in the `managed_node_groups` variable
3. **IAM permissions** for CloudWatch alarms (automatically configured)

## Metrics Source

All metrics come from the **ContainerInsights** namespace, which is enabled through the `aws-cloudwatch-metrics` addon deployed by the `eks_blueprints_addons` module.

## Cost Considerations

- Each alarm costs approximately $0.10/month
- For a cluster with 3 node groups and all alarms enabled:
  - 7 metric alarms × 3 node groups = 21 alarms
  - 1 composite alarm × 3 node groups = 3 alarms
  - Total: 24 alarms ≈ $2.40/month

## Troubleshooting

### Alarms Not Triggering

1. **Verify Container Insights is running:**
   ```bash
   kubectl get pods -n amazon-cloudwatch
   ```

2. **Check metrics are being collected:**
   ```bash
   aws cloudwatch list-metrics \
     --namespace ContainerInsights \
     --dimensions Name=ClusterName,Value=your-cluster-name
   ```

3. **Verify alarm configuration:**
   ```bash
   aws cloudwatch describe-alarms \
     --alarm-name-prefix your-cluster-name
   ```

### Missing Metrics

If metrics aren't appearing:
- Ensure CloudWatch agent has proper IAM permissions
- Check CloudWatch agent logs in the cluster
- Verify Container Insights is enabled in the EKS console

### False Positives

Adjust thresholds if receiving too many alerts:
- Increase `alarm_*_threshold` values
- Increase `alarm_*_evaluation_periods` for longer sustained issues
- Increase `alarm_*_period` for less frequent checks

## Best Practices

1. **Start with defaults** and adjust based on observed patterns
2. **Use SNS topics** to route alerts to appropriate teams
3. **Set up composite alarms** for critical issues requiring immediate attention
4. **Monitor alarm metrics** over time to tune thresholds
5. **Document runbooks** for each alarm type
6. **Test alarms** by artificially triggering conditions in non-production environments

## Integration Examples

### Slack Notifications

```hcl
resource "aws_sns_topic" "eks_alerts" {
  name = "${var.cluster_name}-eks-alerts"
}

resource "aws_sns_topic_subscription" "slack" {
  topic_arn = aws_sns_topic.eks_alerts.arn
  protocol  = "https"
  endpoint  = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
}
```

### PagerDuty Integration

```hcl
resource "aws_sns_topic_subscription" "pagerduty" {
  topic_arn = aws_sns_topic.eks_alerts.arn
  protocol  = "https"
  endpoint  = "https://events.pagerduty.com/integration/YOUR_INTEGRATION_KEY/enqueue"
}
```

### Email Notifications

```hcl
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.eks_alerts.arn
  protocol  = "email"
  endpoint  = "devops@example.com"
}
```

## Monitoring Dashboard

You can create a CloudWatch dashboard to visualize all alarms:

```hcl
resource "aws_cloudwatch_dashboard" "eks_node_groups" {
  dashboard_name = "${var.cluster_name}-node-groups"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            for ng_name in keys(var.managed_node_groups) : [
              "ContainerInsights", "node_cpu_utilization",
              { stat = "Average", label = ng_name }
            ]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Node CPU Utilization"
        }
      }
    ]
  })
}
```
