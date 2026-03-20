variable "cluster_name" {
  description = "Name of the cluster"
}

variable "environment" {
  description = "Name of environment e.g. dev, qa, prod"
}

variable "additional_node_policies_arn" {
  description = "Additional policies for nodes"
}

variable "cluster_version" {
  description = "The kubernetes cluster version"
}

variable "vpc_cidr" {
  description = "CIDR for VPC network"
}

variable "private_subnet_cidrs" {
  description = "CIDR for private sub-network"
}

variable "public_subnet_cidrs" {
  description = "CIDR for public subnetwork"
}

variable "cert_manager_route53_hosted_zone_arns" {
  description = "Hosted zone ARN for Certificate Manager in EKS Cluster"
}

variable "admin_access_role_arn" {
  description = "The ARN of an Admin role in AWS for cluster access"
  default     = ""
}

variable "terraform_runner_access_role_arn" {
  description = "The ARN of the terraform runner role in AWS. This gives the terraform runner access to the EKS cluster to perform kubernetes tasks."
  default     = ""
}

variable "cicd_runner_access_role_arn" {
  description = "The ARN of the CICD runner role in AWS. This gives the CICD runner access to the EKS cluster to perform kubernetes tasks."
  default     = ""
}

variable "poweruser_access_role_arn" {
  description = "The ARN of a power-user role in AWS for cluster access"
  default     = ""
}

variable "read_access_role_arn" {
  description = "The ARN of a read only user role in AWS for cluster access"
  default     = ""
}

variable "managed_node_groups" {
  description = "The managed node group configuration"
}

variable "additional_cluster_security_groud_ids" {
  description = "List of additional security group IDs for cluster endpoint"
}

variable "karpenter" {
  description = "Karpenter nodeclass and nodepool configuration. Set to null to disable Karpenter."
  default     = null
}

variable "external_dns" {
  description = "External dns configurations for aws and cloudflare providers"
}

# CloudWatch Alarms Configuration
variable "cloudwatch_alarms" {
  description = "CloudWatch alarms configuration for EKS node groups"
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

  default = {
    enabled = true
  }
}