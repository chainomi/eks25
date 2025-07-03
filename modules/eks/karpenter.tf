
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
locals {
 karpenter = {
    node_pools = {
          general = {
            ami_family     = "AL2023"
            ami_alias      = "al2023@latest"
            instance_types = ["c5a.4xlarge","c5ad.8xlarge"]
            volume_size    = "50Gi"
            volume_type    = "gp3"
          }
    }
 } 
}
resource "kubectl_manifest" "ec2_node_class" {
  for_each = local.karpenter.node_pools

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
  for_each = local.karpenter.node_pools

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
            }
          ]
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