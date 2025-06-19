
# Atlantis service account role
resource "aws_iam_role" "atlantis_role" {
  name = "atlantis-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.oidc.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(data.aws_iam_openid_connect_provider.oidc.url, "https://", "")}:sub" = "system:serviceaccount:${local.atlantis_namespace}:${local.app_name}"
          }
        }
      }
    ]
  })
}

# Atlantis service account assume role policy
resource "aws_iam_role_policy" "assume_admin_policy" {
  name = "atlantis-assume-admin-role-policy"
  role = aws_iam_role.atlantis_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = local.terraform_admin_role_arn
      }
    ]
  })
}

