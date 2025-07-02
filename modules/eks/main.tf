# data source for Karpenter 
data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.ecr
}

# Create EKS cluster 
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.34.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  authentication_mode                   = "API_AND_CONFIG_MAP"
  cluster_additional_security_group_ids = var.additional_cluster_security_groud_ids
  cluster_endpoint_private_access       = true
  cluster_endpoint_public_access        = true

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    eks-pod-identity-agent = { # this is required for Karpenter to function
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.public_subnets


  # EKS Managed Node Group(s)
  # Note - a security group is automatically created for the node group with rules limiting traffic between the node and other cluster resources
  eks_managed_node_group_defaults = {
    # Use below to add additional sg's as to all managed node groups e.g. efs

    ami_type       = "AL2023_x86_64_STANDARD"
    vpc_security_group_ids = []

    enable_bootstrap_user_data = true
    cloudinit_pre_nodeadm = [{
      content      = <<-EOT
        ---
        apiVersion: node.eks.aws/v1alpha1
        kind: NodeConfig
        spec:
          kubelet:
            config:
              shutdownGracePeriod: 30s
              featureGates:
                DisableKubeletCloudCredentialProviders: true
      EOT
      content_type = "application/node.eks.aws"
    }]
    cloudinit_post_nodeadm = [{ 
      content       = <<-EOT
        sudo ipvsadm --set 3600 120 300
        sudo sysctl net.ipv6.conf.all.disable_ipv6=1
        sudo /usr/sbin/sysctl net.netfilter.nf_conntrack_tcp_be_liberal=1
      EOT 
      content_type = "text/x-shellscript; charset=\"us-ascii\"" 
    }]

    iam_role_additional_policies = {
      additional = var.additional_node_policies_arn
    }
  }

  

  eks_managed_node_groups = var.managed_node_groups

  #  EKS K8s API cluster needs to be able to talk with the EKS worker nodes with port 15017/TCP and 15012/TCP which is used by Istio
  #  Istio in order to create sidecar needs to be able to communicate with webhook and for that network passage to EKS is needed.
  node_security_group_additional_rules = {
    ingress_15017 = {
      description                   = "Cluster API - Istio Webhook namespace.sidecar-injector.istio.io"
      protocol                      = "TCP"
      from_port                     = 15017
      to_port                       = 15017
      type                          = "ingress"
      source_cluster_security_group = true
    }
    ingress_15012 = {
      description                   = "Cluster API to nodes ports/protocols"
      protocol                      = "TCP"
      from_port                     = 15012
      to_port                       = 15012
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  # grant cluster creator role admin access to cluster
  enable_cluster_creator_admin_permissions = var.cicd_runner_access_role_arn != "" ? false : true

  node_security_group_tags = {
    # NOTE - if creating multiple security groups with this module, only tag the
    # security group that Karpenter should utilize with the following tag
    # (i.e. - at most, only one security group should have this tag in your account)
    "karpenter.sh/discovery" = var.cluster_name
  }
  # cluster access for various sso groups. See link below for details on access policies
  # https://docs.aws.amazon.com/eks/latest/userguide/access-policies.html 

  access_entries = merge(
    var.read_access_role_arn != "" ? {
      reader = {
        principal_arn = var.read_access_role_arn

        policy_associations = {
          reader_policy = {
            policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
            access_scope = { type = "cluster" }
          }
        }
      }
    } : {},
    var.poweruser_access_role_arn != "" ? {
      poweruser = {
        principal_arn = var.poweruser_access_role_arn

        policy_associations = {
          power_user_policy = {
            policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
            access_scope = { type = "cluster" }
          }
        }
      }
    } : {},
    var.cicd_runner_access_role_arn != "" ? {
      cicd_runner = {
        principal_arn = var.cicd_runner_access_role_arn

        policy_associations = {
          cicd_user_policy = {
            policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = { type = "cluster" }
          }
        }
      }
    } : {},
    var.admin_access_role_arn != "" ? {
      admin = {
        principal_arn = var.admin_access_role_arn

        policy_associations = {
          admin_policy = {
            policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = { type = "cluster" }
          }
        }
      }
    } : {}
  )
}

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.20.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  eks_addons = {
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn
    }

  }

  enable_aws_efs_csi_driver                    = true
  enable_aws_cloudwatch_metrics                = true
  enable_cluster_autoscaler                    = true
  enable_kube_prometheus_stack                 = true
  enable_metrics_server                        = true
  enable_external_secrets                      = true
  enable_secrets_store_csi_driver              = true
  enable_secrets_store_csi_driver_provider_aws = true
  enable_cert_manager                          = true
  cert_manager_route53_hosted_zone_arns        = var.cert_manager_route53_hosted_zone_arns

  # Turn off mutation webhook for services to avoid ordering issue
  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller = {
    set = [{
      name  = "enableServiceMutatorWebhook"
      value = "false"
    }]
  }

  # helm_releases = {
  #   istio-base = {
  #     chart         = "base"
  #     chart_version = local.istio_chart_version
  #     repository    = local.istio_chart_url
  #     name          = "istio-base"
  #     namespace     = local.istio_namespace
  #   }

  #   istiod = {
  #     chart         = "istiod"
  #     chart_version = local.istio_chart_version
  #     repository    = local.istio_chart_url
  #     name          = "istiod"
  #     namespace     = local.istio_namespace

  #     set = [
  #       {
  #         name  = "meshConfig.accessLogFile"
  #         value = "/dev/stdout"
  #       }
  #     ]
  #   }

  #   istio-ingress = {
  #     chart            = "gateway"
  #     chart_version    = local.istio_chart_version
  #     repository       = local.istio_chart_url
  #     name             = "istio-ingress"
  #     namespace        = "istio-ingress" # per https://github.com/istio/istio/blob/master/manifests/charts/gateways/istio-ingress/values.yaml#L2
  #     create_namespace = true

  #     values = [
  #       yamlencode(
  #         {
  #           labels = {
  #             istio = "ingressgateway"
  #           }
  #           service = {
  #             type = "ClusterIP"
  #             annotations = {
  #               # "service.beta.kubernetes.io/aws-load-balancer-type"            = "external"
  #               # "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
  #               # "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internet-facing"
  #               # "service.beta.kubernetes.io/aws-load-balancer-attributes"      = "load_balancing.cross_zone.enabled=true"
  #             }
  #           }
  #         }
  #       )
  #     ]
  #   }
  # }

  depends_on = [module.eks, kubectl_manifest.istio_namespace]
}

module "ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.20"

  role_name_prefix = "${var.cluster_name}-ebs-csi-driver-"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

module "eks_ack_addons" {
  source = "aws-ia/eks-ack-addons/aws"

  # Cluster Info
  cluster_name      = var.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  oidc_provider_arn = module.eks.oidc_provider_arn

  # Controllers to enable
  enable_iam = true
  enable_s3  = true
  enable_rds = true
}

# This module updates the Route 53 record for the ingress domain with the proper alb dns address 

# module "external_dns" {
#   source = "git::https://github.com/DNXLabs/terraform-aws-eks-external-dns.git"

#   cluster_identity_oidc_issuer     = module.eks.cluster_oidc_issuer_url
#   cluster_identity_oidc_issuer_arn = module.eks.oidc_provider_arn
#   cluster_name                     = module.eks.cluster_name
#   helm_chart_version               = "6.14.4"

#   settings = {
#     "policy"     = "sync"                       # Modify how DNS records are sychronized between sources and providers.
#     "txtOwnerId" = "${var.cluster_name}-domain" #unique identifier for each external DNS instance
#   }
#   # Helm chart repo - https://artifacthub.io/packages/helm/bitnami/external-dns
#   # Module repo - https://github.com/DNXLabs/terraform-aws-eks-external-dns

# }

locals {
  karpenter_role_name = "karpenter-role"
}

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "20.34.0"

  cluster_name = module.eks.cluster_name

  enable_v1_permissions = true

  enable_pod_identity             = true
  create_pod_identity_association = true

  # Name needs to match role name passed to the EC2NodeClass
  node_iam_role_name = local.karpenter_role_name


  # Used to attach additional IAM policies to the Karpenter node IAM role
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
}

resource "helm_release" "karpenter" {
  namespace           = "kube-system"
  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = "1.1.1"
  wait                = false

  values = [
    <<-EOT
    serviceAccount:
      name: ${module.karpenter.service_account}    
    nodeSelector:
      karpenter.sh/controller: 'true'
    dnsPolicy: Default
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}
    webhook:
      enabled: false      
    EOT
  ]
  depends_on = [module.karpenter]
}