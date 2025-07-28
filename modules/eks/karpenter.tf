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

resource "kubectl_manifest" "ec2_node_class" {
  for_each = var.karpenter.node_pools

  yaml_body = yamlencode({
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = each.key
    }
    spec = {
      amiFamily = each.value.ami_family
      amiSelectorTerms = [
        {
          alias = each.value.ami_alias
        }
      ]
      userData = <<-EOT
        #!/bin/bash
        sudo ipvsadm --set 3600 120 300
        sudo sysctl net.ipv6.conf.all.disable_ipv6=1
        sudo /usr/sbin/sysctl net.netfilter.nf_conntrack_tcp_be_liberal=1
      EOT
      role     = module.karpenter.node_iam_role_name
      blockDeviceMappings = [
        {
          deviceName = "/dev/xvda"
          ebs = {
            volumeSize = each.value.volume_size
            volumeType = each.value.volume_type
            encrypted  = true
          }
        }
      ]
      subnetSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = module.eks.cluster_name
          }
        }
      ]
      securityGroupSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = module.eks.cluster_name
          }
        }
      ]
      tags = {
        Name                     = "karpenter-${each.key}-node-group"
        "karpenter.sh/discovery" = module.eks.cluster_name
      }
    }
  })
  depends_on = [
    helm_release.karpenter
  ]
}

resource "kubectl_manifest" "nodepool" {
  for_each = var.karpenter.node_pools

  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = each.key
    }
    spec = {
      template = {
        spec = {
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = each.key
          }
          requirements = [
            {
              key      = "node.kubernetes.io/instance-type"
              operator = "In"
              values   = each.value.instance_types
            },
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = each.value.capacity_type
            }
          ]
        }
        metadata = {
          labels = each.value.labels
        }
      }
      limits = {
        cpu = 1000
      }
      disruption = {
        consolidationPolicy = "WhenEmpty"
        consolidateAfter    = "30s"
      }
    }
  })
  depends_on = [
    kubectl_manifest.ec2_node_class
  ]
}





# resource "kubectl_manifest" "karpenter_node_class" {
#   yaml_body = <<-YAML
#     apiVersion: karpenter.k8s.aws/v1
#     kind: EC2NodeClass
#     metadata:
#       name: default
#     spec:
#       amiFamily: AL2023
#       amiSelectorTerms:
#         - alias: al2023@latest
#       userData: |
#         #!/bin/bash
#         sudo ipvsadm --set 3600 120 300
#         sudo sysctl net.ipv6.conf.all.disable_ipv6=1
#         sudo /usr/sbin/sysctl net.netfilter.nf_conntrack_tcp_be_liberal=1

#       role: ${module.karpenter.node_iam_role_name}
#       blockDeviceMappings:
#         - deviceName: /dev/xvda
#           ebs:
#             volumeSize: 50Gi
#             volumeType: gp3
#             encrypted: true

#       subnetSelectorTerms:
#         - tags:
#             karpenter.sh/discovery: ${module.eks.cluster_name}
#       securityGroupSelectorTerms:
#         - tags:
#             karpenter.sh/discovery: ${module.eks.cluster_name}
#       tags:
#         Name: karpenter-node-group
#         karpenter.sh/discovery: ${module.eks.cluster_name}
#   YAML

#   depends_on = [
#     helm_release.karpenter
#   ]
# }

# resource "kubectl_manifest" "karpenter_node_pool" {
#   yaml_body = <<-YAML
#     apiVersion: karpenter.sh/v1
#     kind: NodePool
#     metadata:
#       name: default
#     spec:
#       template:
#         spec:
#           nodeClassRef:
#             group: karpenter.k8s.aws
#             kind: EC2NodeClass
#             name: default
#           requirements:
#             - key: "karpenter.k8s.aws/instance-category"
#               operator: In
#               values: ["c", "m", "r"]
#             - key: "karpenter.k8s.aws/instance-cpu"
#               operator: In
#               values: ["4", "8", "16", "32"]
#             - key: "karpenter.k8s.aws/instance-hypervisor"
#               operator: In
#               values: ["nitro"]
#             - key: "karpenter.k8s.aws/instance-generation"
#               operator: Gt
#               values: ["2"]
#       limits:
#         cpu: 1000
#       disruption:
#         consolidationPolicy: WhenEmpty
#         consolidateAfter: 30s
#   YAML

#   depends_on = [
#     kubectl_manifest.karpenter_node_class
#   ]
# }