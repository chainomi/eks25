# ArgoCD service account IAM role for production cluster deployments

resource "aws_iam_role" "argo_cicd" {
  name = "argocd-cicd"

  description = "IAM role for ArgoCD k8s service account - used to assume eks-cicd role in development and production accounts for k8s resource deployments to development and production EKS clusters"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRoleWithWebIdentity"
        Principal = { Federated = "${data.aws_iam_openid_connect_provider.cluster.arn}" }
        Condition = {
          StringEquals = {
            "${data.aws_iam_openid_connect_provider.cluster.url}:sub" = [
              "system:serviceaccount:${local.argocd_namespace}:${local.argocd_service_account_name}",
              "system:serviceaccount:${local.argocd_namespace}:${local.argocd_application_controller_service_account_name}"
            ],
            "${data.aws_iam_openid_connect_provider.cluster.url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  inline_policy {
    name = "assume-role"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = ["sts:AssumeRole"]
          Effect   = "Allow"
          Resource = "*"
        },
      ]
    })
  }

}

