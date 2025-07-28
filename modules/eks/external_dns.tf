data "aws_region" "current" {}

locals {
  region = data.aws_region.current.name
  external_dns = {
    chart_url     = "https://charts.bitnami.com/bitnami"
    chart_version = "6.14.4"
    namespace     = "kube-system"

  }
}

resource "helm_release" "external_dns_aws" {
  count = length(try(var.external_dns.aws, {})) > 0 ? 1 : 0

  chart      = "external-dns"
  namespace  = local.external_dns.namespace
  name       = "external-dns-aws"
  version    = local.external_dns.chart_version
  repository = local.external_dns.chart_url


  values = [
    yamlencode({
      provider = "aws"
      aws = {
        region = "${local.region}"
      }
      policy        = "sync"
      txtOwnerId    = "${var.cluster_name}-domain"
      domain_filter = []
      rbac = {
        create = true
      }
      serviceAccount = {
        name   = "${var.external_dns.aws.service_account_name}"
        create = true
        annotations = {
          "eks.amazonaws.com/role-arn" = "${aws_iam_role.external_dns.arn}"
        }
      }
    })
  ]
}

resource "helm_release" "external_dns_cloudflare" {
  count = length(try(var.external_dns.cloudflare, {})) > 0 ? 1 : 0

  chart      = "external-dns"
  namespace  = local.external_dns.namespace
  name       = "external-dns-cloudflare"
  version    = local.external_dns.chart_version
  repository = local.external_dns.chart_url


  values = [
    yamlencode({
      provider   = "cloudflare"
      policy     = "sync"
      txtOwnerId = "${var.cluster_name}-domain"
      rbac = {
        create = true
      }
      serviceAccount = {
        name   = "${var.external_dns.cloudflare.service_account_name}"
        create = true
      }
      cloudflare = {
        apiToken = "${var.external_dns.cloudflare.api_token}"
      }
    })
  ]
}



# IRSA for aws external dns instance
data "aws_iam_policy_document" "external_dns" {
  statement {
    sid = "ChangeResourceRecordSets"

    actions = [
      "route53:ChangeResourceRecordSets",
    ]

    resources = [for id in var.external_dns.aws.allowed_hosted_zone_ids : "arn:aws:route53:::hostedzone/${id}"]

    effect = "Allow"
  }

  statement {
    sid = "ListResourceRecordSets"

    actions = [
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets",
      "route53:ListTagsForResource",
    ]

    resources = [
      "*",
    ]

    effect = "Allow"
  }
}

resource "aws_iam_policy" "external_dns" {
  name        = "${var.cluster_name}-external-dns-policy"
  path        = "/"
  description = "Policy for external-dns service"

  policy = data.aws_iam_policy_document.external_dns.json
}

# Role
data "aws_iam_policy_document" "external_dns_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"

      values = [
        "system:serviceaccount:${local.external_dns.namespace}:${var.external_dns.aws.service_account_name}",
      ]
    }

    effect = "Allow"
  }
}

resource "aws_iam_role" "external_dns" {
  name               = "${var.cluster_name}-external-dns-role"
  assume_role_policy = data.aws_iam_policy_document.external_dns_assume.json
}

resource "aws_iam_role_policy_attachment" "external_dns" {
  role       = aws_iam_role.external_dns.name
  policy_arn = aws_iam_policy.external_dns.arn
}



