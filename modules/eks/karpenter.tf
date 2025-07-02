
resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      amiFamily: AL2023
      amiSelectorTerms:
        - alias: al2023@latest
      userData: |
        #!/bin/bash
        sudo ipvsadm --set 3600 120 300
        sudo sysctl net.ipv6.conf.all.disable_ipv6=1
        sudo /usr/sbin/sysctl net.netfilter.nf_conntrack_tcp_be_liberal=1
      
      role: ${module.karpenter.node_iam_role_name}
      blockDeviceMappings:
        - deviceName: /dev/xvda
          ebs:
            volumeSize: 50Gi
            volumeType: gp3
            encrypted: true
                 
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      tags:
        Name: karpenter-node-group
        karpenter.sh/discovery: ${module.eks.cluster_name}
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}

resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: default
    spec:
      template:
        spec:
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: default
          requirements:
            - key: "karpenter.k8s.aws/instance-category"
              operator: In
              values: ["c", "m", "r"]
            - key: "karpenter.k8s.aws/instance-cpu"
              operator: In
              values: ["4", "8", "16", "32"]
            - key: "karpenter.k8s.aws/instance-hypervisor"
              operator: In
              values: ["nitro"]
            - key: "karpenter.k8s.aws/instance-generation"
              operator: Gt
              values: ["2"]
      limits:
        cpu: 1000
      disruption:
        consolidationPolicy: WhenEmpty
        consolidateAfter: 30s
  YAML

  depends_on = [
    kubectl_manifest.karpenter_node_class
  ]
}



#       userdata: |
# MIME-Version: 1.0
# Content-Type: multipart/mixed; boundary="BOUNDARY"

# --BOUNDARY
# Content-Type: application/node.eks.aws

# ---
# apiVersion: node.eks.aws/v1alpha1
# kind: NodeConfig
# spec:
#   cluster:
#     name: ${var.cluster_name}
#     apiServerEndpoint: ${module.eks.cluster_endpoint}
#     certificateAuthority: ${base64decode(module.eks.cluster_certificate_authority_data)}
#     cidr: ${module.eks.cluster_service_cidr}

# --BOUNDARY
# Content-Type: application/node.eks.aws

# ---
# apiVersion: node.eks.aws/v1alpha1
# kind: NodeConfig
# spec:
#   kubelet:
#     config:
#       shutdownGracePeriod: 30s
#       featureGates:
#         DisableKubeletCloudCredentialProviders: true

# --BOUNDARY
# Content-Type: text/x-shellscript; charset="us-ascii"

# #!/bin/bash
# sudo ipvsadm --set 3600 120 300
# sudo sysctl net.ipv6.conf.all.disable_ipv6=1
# sudo /usr/sbin/sysctl net.netfilter.nf_conntrack_tcp_be_liberal=1

# --BOUNDARY-- 
