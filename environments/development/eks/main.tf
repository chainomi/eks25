# General 
locals {
  region           = "us-west-1"
  application_name = "eks"
  environment      = "development"
  cluster_name     = "${local.environment}-${local.application_name}"
}

data "aws_caller_identity" "current" {}

# EKS cluster 
module "eks" {
  source          = "../../../modules/eks/"
  environment     = local.environment
  cluster_name    = local.cluster_name
  cluster_version = "1.31"

  # AWS managed nodes configuration
  # https://docs.aws.amazon.com/eks/latest/APIReference/API_Nodegroup.html#AmazonEKS-Type-Nodegroup-amiType

  additional_node_policies_arn          = aws_iam_policy.additional_node_policy.arn
  additional_cluster_security_groud_ids = [aws_security_group.cluster_access.id]

  managed_node_groups = {
    "core-node-group" = {
      min_size     = 2
      max_size     = 2
      desired_size = 2
      disk_size    = 50

      instance_types = ["m5.large"]
      capacity_type  = "ON_DEMAND"

      labels = {
        WorkerType                = "ON_DEMAND"
        NodeGroupType             = "core"
        environment               = local.environment
        "karpenter.sh/controller" = "true" # Allow Karpenter controller run on node
      }

      tags = {
        Name = "core-node-group"
      }
    }
  }

  karpenter = {
    node_pools = {
      general = {
        ami_family     = "AL2023"
        ami_alias      = "al2023@latest"
        instance_types = ["c5a.4xlarge", "c5ad.8xlarge"]
        capacity_type  = ["on-demand"]
        volume_size    = "50Gi"
        volume_type    = "gp3"

        labels = {
          WorkerType    = "ON_DEMAND"
          NodeGroupType = "karpenter"
          environment   = local.environment
        }
      }
    }
  }

  # Networking
  vpc_cidr             = "10.0.0.0/16"
  private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24"]

  # Cert manager
  cert_manager_route53_hosted_zone_arns = ["*"]

  external_dns = {
    aws = {
      service_account_name    = "external-dns-aws"
      domain_filter           = ["*"]
      allowed_hosted_zone_ids = ["*"]
    }
    # cloudflare = {
    #   service_account_name = "external-dns-cloudflare"
    #   api_token            = ""
    #   domain_filter        = ["*"]
    # }
  }
  # Cluster access
  cicd_runner_access_role_arn = "arn:aws:iam::488144151286:user/chainomi"

}

# EKS cluster 
module "ecr" {
  source               = "../../../modules/ecr/"
  repo_list            = ["flask-api"]
  image_tag_mutability = "MUTABLE"
}



# # testing cloning in helm chart from repo
# locals {
#  repo_org = "chainomi"
#  repos = [
#    "some-chart-2023-09-29"
#  ]
#  repo_download_location = "repos"
# }
# resource "null_resource" "download_chart" {
#   for_each = toset(local.repos)
#   provisioner "local-exec" {
#     command = <<EOT
#       rm -rf ${repo_download_location}/*
#       git clone --depth 1 --branch main https://github.com/${local.repo_org}/${each.repos}.git ${repo_download_location}/${each.repos}
#     EOT
#   }
# }

# # Step 2: Use local path to install the chart
# resource "helm_release" "my_app" {
#   name       = "my-app"
#   chart      = "/${repo_download_location}/some-chart-2023-09-29/flask-api-chart"
#   depends_on = [null_resource.download_chart]
#   values     = [
#     file("/${repo_download_location}/some-chart-2023-09-29/flask-api-chart/values.yaml")
#   ]
# }

