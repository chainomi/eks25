# EKS Module

Opinionated EKS cluster module built on top of [`terraform-aws-modules/eks/aws`](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest) v21. Provisions a fully functional EKS cluster with managed node groups, Karpenter autoscaling, Istio service mesh, External DNS, CloudWatch alarms, and a standard set of add-ons.

## What's included

| Component | Details |
|---|---|
| EKS Cluster | v1.31+, API + ConfigMap auth, public/private endpoint |
| VPC | Dedicated VPC with public/private subnets |
| Managed node groups | Configurable per-group, AL2023 AMI, IPVS tuning via cloud-init |
| Karpenter | v1.1.1, pod identity, SQS interruption handling — **optional** |
| Istio | Istio base + istiod + ingress gateway |
| External DNS | AWS Route53 and/or Cloudflare providers |
| CloudWatch Alarms | CPU, memory, disk, network, node count, pod count |
| EKS Add-ons | coredns, kube-proxy, vpc-cni, eks-pod-identity-agent, aws-ebs-csi-driver, aws-efs-csi-driver |
| Blueprint Add-ons | cluster-autoscaler, kube-prometheus-stack, metrics-server, external-secrets, secrets-store-csi-driver, cert-manager, aws-load-balancer-controller |
| ACK Controllers | IAM, S3, RDS |

## Required providers

```hcl
terraform {
  required_version = ">=1.5.7"

  required_providers {
    aws        = { source = "hashicorp/aws",    version = "~> 6.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = ">= 2.10" }
    kubectl    = { source = "gavinbunney/kubectl",  version = ">= 1.19.0" }
    helm       = { source = "hashicorp/helm",    version = "2.17.0" }
  }
}

# Required: aliased provider for ECR public (must be us-east-1)
provider "aws" {
  alias  = "ecr"
  region = "us-east-1"
}
```

## Usage

### Minimal

```hcl
module "eks" {
  source          = "../../../modules/eks/"
  environment     = "development"
  cluster_name    = "development-eks"
  cluster_version = "1.31"

  additional_node_policies_arn          = aws_iam_policy.node_policy.arn
  additional_cluster_security_groud_ids = []

  managed_node_groups = {
    "core" = {
      min_size       = 2
      max_size       = 4
      desired_size   = 2
      disk_size      = 50
      instance_types = ["m5.large"]
      capacity_type  = "ON_DEMAND"
      labels         = { NodeGroupType = "core" }
      tags           = { Name = "core" }
    }
  }

  vpc_cidr             = "10.0.0.0/16"
  private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24"]

  cert_manager_route53_hosted_zone_arns = ["*"]

  external_dns = {
    aws = {
      service_account_name    = "external-dns-aws"
      domain_filter           = ["*"]
      allowed_hosted_zone_ids = ["*"]
    }
  }
}
```

### With Karpenter — broad instance selection (recommended)

Omit `instance_types` and use `instance_category` / `instance_generation` / `arch` to let Karpenter pick the best available instance:

```hcl
karpenter = {
  node_pools = {
    general = {
      ami_family = "AL2023"
      ami_alias  = "al2023@latest"

      # Karpenter selects any c/m/r instance, generation > 4, amd64
      instance_category   = ["c", "m", "r"]
      instance_generation = "4"          # Gt operator — must be a string
      arch                = ["amd64"]

      capacity_type = ["on-demand"]
      volume_size   = "50Gi"
      volume_type   = "gp3"

      labels = {
        WorkerType    = "ON_DEMAND"
        NodeGroupType = "karpenter"
        environment   = "development"
      }
    }
  }
}
```

### With Karpenter — pinned instance types

Set `instance_types` to restrict to exact instance types. When set, `instance_category`, `instance_generation`, and `arch` are ignored.

```hcl
karpenter = {
  node_pools = {
    general = {
      ami_family     = "AL2023"
      ami_alias      = "al2023@latest"
      instance_types = ["m5.large", "m5.xlarge", "c5.xlarge"]
      capacity_type  = ["on-demand", "spot"]
      volume_size    = "50Gi"
      volume_type    = "gp3"
      labels         = { NodeGroupType = "karpenter" }
    }
  }
}
```

### Without Karpenter

Set `karpenter = null` or omit the variable entirely. No Karpenter IAM roles, Helm release, NodePools, or EC2NodeClasses are created.

```hcl
module "eks" {
  # ...
  karpenter = null
}
```

## Input variables

### Required

| Name | Description |
|---|---|
| `cluster_name` | Name of the EKS cluster |
| `environment` | Environment label e.g. `development`, `production` |
| `cluster_version` | Kubernetes version e.g. `"1.31"` |
| `additional_node_policies_arn` | ARN of an additional IAM policy attached to all node groups |
| `additional_cluster_security_groud_ids` | List of additional security group IDs for the cluster endpoint |
| `managed_node_groups` | Map of managed node group configurations (see below) |
| `vpc_cidr` | CIDR block for the VPC |
| `private_subnet_cidrs` | List of private subnet CIDRs |
| `public_subnet_cidrs` | List of public subnet CIDRs |
| `cert_manager_route53_hosted_zone_arns` | Route53 hosted zone ARNs for cert-manager |
| `external_dns` | External DNS configuration (see below) |

### Optional

| Name | Default | Description |
|---|---|---|
| `karpenter` | `null` | Karpenter configuration. Set to `null` to disable. |
| `admin_access_role_arn` | `""` | ARN of an admin IAM role for cluster access |
| `cicd_runner_access_role_arn` | `""` | ARN of a CI/CD runner IAM role (cluster admin) |
| `terraform_runner_access_role_arn` | `""` | ARN of a Terraform runner IAM role |
| `poweruser_access_role_arn` | `""` | ARN of a power-user IAM role (EKS admin policy) |
| `read_access_role_arn` | `""` | ARN of a read-only IAM role (EKS view policy) |
| `cloudwatch_alarms` | enabled with defaults | CloudWatch alarm configuration (see below) |

## managed_node_groups

Each key in the map becomes a node group name. Fields:

```hcl
managed_node_groups = {
  "node-group-name" = {
    min_size       = number
    max_size       = number
    desired_size   = number
    disk_size      = number           # GB
    instance_types = list(string)
    capacity_type  = string           # "ON_DEMAND" or "SPOT"
    labels         = map(string)
    tags           = map(string)
  }
}
```

To allow the Karpenter controller to run on a node group, add the label:

```hcl
labels = {
  "karpenter.sh/controller" = "true"
}
```

## karpenter

```hcl
karpenter = {
  node_pools = {
    "<pool-name>" = {
      ami_family = string           # e.g. "AL2023"
      ami_alias  = string           # e.g. "al2023@latest"
      volume_size = string          # e.g. "50Gi"
      volume_type = string          # e.g. "gp3"
      capacity_type = list(string)  # ["on-demand"] or ["spot"] or both
      labels        = map(string)

      # Option A — pin to exact instance types (overrides B)
      instance_types = list(string) # e.g. ["m5.large", "c5.xlarge"]

      # Option B — broad filters (used only when instance_types is omitted/null)
      instance_category   = list(string) # e.g. ["c", "m", "r"]
      instance_generation = string       # minimum generation, Gt operator e.g. "4"
      arch                = list(string) # e.g. ["amd64"]
    }
  }
}
```

**Option A vs Option B are mutually exclusive.** When `instance_types` is set, Options B fields are ignored. When `instance_types` is omitted or `null`, Options B fields each independently add a requirement — any can be omitted.

## external_dns

```hcl
external_dns = {
  # AWS Route53 provider (optional)
  aws = {
    service_account_name    = string       # K8s service account name
    domain_filter           = list(string) # e.g. ["example.com"] or ["*"]
    allowed_hosted_zone_ids = list(string) # e.g. ["Z1234567890"] or ["*"]
  }

  # Cloudflare provider (optional)
  cloudflare = {
    service_account_name = string
    api_token            = string
    domain_filter        = list(string)
  }
}
```

Both `aws` and `cloudflare` keys are optional. Omit a key entirely to skip that provider.

## cloudwatch_alarms

```hcl
cloudwatch_alarms = {
  enabled       = bool           # default: true
  sns_topic_arn = string         # ARN to notify on alarm

  cpu = {
    threshold          = number  # default: 80 (percent)
    period             = number  # default: 300 (seconds)
    evaluation_periods = number  # default: 2
  }

  memory = {
    threshold          = number  # default: 80
    period             = number  # default: 300
    evaluation_periods = number  # default: 2
  }

  disk = {
    threshold          = number  # default: 85
    period             = number  # default: 300
    evaluation_periods = number  # default: 2
  }

  node_count = {
    period             = number  # default: 300
    evaluation_periods = number  # default: 2
  }

  network = {
    errors_threshold   = number  # default: 10
    period             = number  # default: 300
    evaluation_periods = number  # default: 2
  }

  node_status = {
    period             = number  # default: 300
    evaluation_periods = number  # default: 2
  }

  pod_count = {
    threshold          = number  # default: 100
    period             = number  # default: 300
    evaluation_periods = number  # default: 2
  }
}
```

All nested objects are optional — only override what you need.

## Outputs

| Name | Description |
|---|---|
| `cluster_id` | EKS cluster ID |
| `cluster_name` | EKS cluster name |
| `cluster_endpoint` | EKS API server endpoint |
| `cluster_primary_security_group_id` | Cluster control plane security group ID |
| `node_security_group_id` | Node group security group ID |
| `oidc_arn` | OIDC provider ARN |
| `oidc_issuer_url` | OIDC issuer URL |
| `vpc_id` | VPC ID |
| `cloudwatch_alarm_arns` | Map of CloudWatch alarm ARNs |
| `cloudwatch_alarm_names` | List of all CloudWatch alarm names |
