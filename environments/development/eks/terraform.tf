locals {
  tags = {
    Terraform      = "true"
    TerraformStack = "eks-${local.application_name}"
    Environment    = local.environment
  }
}

terraform {
  required_version = "~> 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.10"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
  }

  backend "s3" {
    bucket  = "chainomi-eks-testing2023"
    key     = "dev/karpenter-demo/terraform.tfstate"
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
