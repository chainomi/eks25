# Data source - management account - for helm provider
data "aws_eks_cluster" "cluster" {
  name = local.cluster_name
}

## Get oidc arn for service account policy
data "aws_iam_openid_connect_provider" "cluster" {
  url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer # Replace with your OIDC provider URL
}

# Data source - development account - for helm chart values
# data "aws_eks_cluster" "eks_dev" {
#   provider = aws.dev
#   name     = local.development_eks_cluster_name
# }

# Data source - production account - for helm chart values
# data "aws_eks_cluster" "eks_prod" {
#   provider = aws.prod
#   name     = local.production_eks_cluster_name
# }

# Data source for gitlab repo secret from
data "aws_secretsmanager_secret_version" "github" {
  secret_id = local.argocd_secret_name
}

