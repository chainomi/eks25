# Created by the generate script
locals {
  tags = {
    Terraform      = "true"
    TerraformStack = "atlantis"
    Environment    = local.environment
  }
}

terraform {
  # required_version = "~> 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.17.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.10"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
    dns = {
      source  = "hashicorp/dns"
      version = "~> 3"
    }
  }

  backend "s3" {
    bucket  = "chainomi-eks-testing2023"
    key     = "dev/argocd/terraform.tfstate"
    region  = "us-west-1"
    encrypt = true
  }
}

provider "aws" {
  region = local.region

  default_tags {
    tags = local.tags
  }
}

# provider "aws" {
#   alias  = "dev"
#   region = "us-east-1"

#   assume_role {
#     role_arn = "arn:aws:iam::XXXXX:role/terraform"
#   }
# }

# provider "aws" {
#   alias  = "prod"
#   region = "us-east-1"

#   assume_role {
#     role_arn = "arn:aws:iam::XXXXX:role/terraform"
#   }
# }

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", local.cluster_name]
    command     = "aws"
  }
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", local.cluster_name]
      command     = "aws"
    }
  }
}

provider "kubectl" {
  apply_retry_count      = 15
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  load_config_file       = false
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", local.cluster_name]
    command     = "aws"
  }
}
