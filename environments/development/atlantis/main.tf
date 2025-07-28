locals {
  region       = "us-west-1"
  environment  = "development"
  cluster_name = "development-eks"
  app_name     = "atlantis"

  atlantis_namespace           = local.app_name
  atlantis_chart_version       = "5.17.2"
  github_secret_name           = "gh_atlantis"
  atlantis_basic_auth_username = jsondecode(data.aws_secretsmanager_secret_version.current.secret_string)["web_username"]
  atlantis_basic_auth_password = jsondecode(data.aws_secretsmanager_secret_version.current.secret_string)["web_password"]
  atlantis_service_account = {
    name       = local.app_name
    annotation = "eks.amazonaws.com/role-arn: ${aws_iam_role.atlantis_role.arn}"
    arn        = "${aws_iam_role.atlantis_role.arn}"
  }
  atlantis_identifier = "${local.app_name}-app"
  terraform_admin_role_arn = aws_iam_role.admin_role.arn
  # github_user              = jsondecode(data.aws_secretsmanager_secret_version.current.secret_string)["user"]
  # github_token_secret      = jsondecode(data.aws_secretsmanager_secret_version.current.secret_string)["token"]
  github_app_id              = jsondecode(data.aws_secretsmanager_secret_version.current.secret_string)["gh_app_id"]
  github_app_installation_id = jsondecode(data.aws_secretsmanager_secret_version.current.secret_string)["gh_app_installation_id"]
  github_app_private_key     = jsondecode(data.aws_secretsmanager_secret_version.current.secret_string)["gh_app_private_key"]
  github_webhook_secret      = jsondecode(data.aws_secretsmanager_secret_version.current.secret_string)["webhook_secret"]
  atlantis_domain            = "atlantis.chainomi.link"
  org_allowlist              = "github.com/chainomi/terraform-workflow"
  alb_cert_arn               = "arn:aws:acm:us-west-1:488144151286:certificate/b1c9bf2e-31c3-4cd9-83de-d09fae059f7a"
  alb_success_codes          = "200,302,401"
  persistent_volume = {
    storage_class_name = "ebs-sc"
    storage_size       = "10Gi"
    ebs_volume_type    = "gp3"
    filesystem_type    = "ext4"
  }


}

# Deploy Atlantis using the Helm chart
resource "helm_release" "atlantis" {
  name       = "atlantis"
  repository = "https://runatlantis.github.io/helm-charts"
  chart      = "atlantis"
  version    = local.atlantis_chart_version # Specify a chart version for stable deployments
  namespace  = local.atlantis_namespace

  # Create the namespace if it doesn't exist
  create_namespace = true

  # Values for the Atlantis Helm chart
  # Refer to the official Atlantis Helm chart documentation for all available options:
  # https://github.com/runatlantis/helm-charts/blob/main/charts/atlantis/values.yaml

  values = [templatefile("./helm/values.yaml",
    {
      org_allowlist = local.org_allowlist
      # github_user                  = local.github_user
      # github_token_secret          = local.github_token_secret
      github_app_id                = local.github_app_id
      github_app_installation_id   = local.github_app_installation_id
      github_app_private_key       = local.github_app_private_key
      github_webhook_secret        = local.github_webhook_secret
      app_name                     = local.app_name
      service_account_name         = local.atlantis_service_account.name
      service_account_annotation   = local.atlantis_service_account.annotation
      alb_cert_arn                 = local.alb_cert_arn
      alb_success_codes            = local.alb_success_codes
      atlantis_domain              = local.atlantis_domain
      atlantis_basic_auth_username = local.atlantis_basic_auth_username
      atlantis_basic_auth_password = local.atlantis_basic_auth_password
      storage_class_name           = local.persistent_volume.storage_class_name
      storage_size                 = local.persistent_volume.storage_size
  })]
  depends_on = [kubectl_manifest.atlantis_persistent_volume]
}


# You might need to define a data source or resource for the service to get its LB hostname/IP
# This is a simplified example, getting the service details might require a separate `kubernetes_service` data source
# or waiting for the Helm release to fully populate service status. For now, we'll use a placeholder.
# This assumes you name your service 'atlantis' within the Helm chart, which is typical.

resource "kubectl_manifest" "atlantis_persistent_volume" {
  yaml_body = <<YAML
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ${local.persistent_volume.storage_class_name}
provisioner: ebs.csi.aws.com
parameters:
  type: ${local.persistent_volume.ebs_volume_type}          # You can use gp2, gp3, io1, etc.
  fsType: ${local.persistent_volume.filesystem_type}
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
YAML
}