# Data source to get EKS cluster information
# This assumes your EKS cluster is already created and you can reference it.
data "aws_eks_cluster" "cluster" {
  name = local.cluster_name
}

# Secret manager - retrieve jenkins admin password

# data "aws_secretsmanager_secret" "kubecost" {
#   name = local.kubecost_secret_name
# }

# data "aws_secretsmanager_secret_version" "kubecost_current" {
#   secret_id = data.aws_secretsmanager_secret.kubecost.id
# }

data "aws_iam_openid_connect_provider" "oidc" {
  url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}
