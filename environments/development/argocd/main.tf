# Config
# =============================================================================
locals {
  # General
  name        = "argocd"
  region      = "us-west-1"
  environment = "development"

  # Cluster
  cluster_name = "development-eks"
  # development_eks_cluster_name = ""
  # production_eks_cluster_name  = ""

  # ArgoCD
  argocd_namespace                                   = "argocd"
  argocd_service_account_name                        = "argocd-server"
  argocd_application_controller_service_account_name = "argocd-application-controller"
  argocd_admin_password                              = bcrypt(jsondecode(data.aws_secretsmanager_secret_version.github.secret_string)["admin_password"])
  argocd_secret_name                                 = "argocd"

  # DNS
  domain       = "argocd.chainomi.link"
  alb_cert_arn = "arn:aws:acm:us-west-1:488144151286:certificate/b1c9bf2e-31c3-4cd9-83de-d09fae059f7a"

  # Repo information
  github_org_url             = "https://github.com/chainomi"
  github_repo_name           = "flask-app-argocd-demo"
  github_repo_url            = "https://github.com/chainomi/flask-app-argocd-demo"
  github_app_id              = jsondecode(data.aws_secretsmanager_secret_version.github.secret_string)["gh_app_id"]
  github_app_installation_id = jsondecode(data.aws_secretsmanager_secret_version.github.secret_string)["gh_app_install_id"]
  github_app_private_key     = jsondecode(data.aws_secretsmanager_secret_version.github.secret_string)["gh_app_private_key"]
  # github_webhook_secret = jsondecode(data.aws_secretsmanager_secret_version.github.secret_string)["gh_webhook_secret"]
  # SSO - Azure OIDC
  # azure_directory_tenant_id = jsondecode(data.aws_secretsmanager_secret_version.github.secret_string)["azure_directory_tenant_id"]
  # azure_group_object_ids = {
  #   systems_team = jsondecode(data.aws_secretsmanager_secret_version.github.secret_string)["azure_group_object_id_systems_team"]
  # }
  # azure_ad_application_client_id = jsondecode(data.aws_secretsmanager_secret_version.github.secret_string)["azure_application_client_id"]
  # azure_client_secret            = jsondecode(data.aws_secretsmanager_secret_version.github.secret_string)["azure_client_secret"]

}

# Helm Chart for ArgoCD
# =============================================================================
resource "helm_release" "argo-cd" {
  name             = "argo-cd"
  version          = "8.2.0"
  namespace        = local.argocd_namespace
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  create_namespace = true

  values = [templatefile("${path.module}/helm-values/values.yaml",
    {
      name   = local.name
      domain = local.domain

      # access
      argocd_admin_password = local.argocd_admin_password

      # ingress (alb) config
      alb_cert_arn = local.alb_cert_arn

      # cluster config
      # development_cluster_name       = local.development_eks_cluster_name
      # development_cluster_api_server = data.aws_eks_cluster.eks_dev.endpoint
      # development_cluster_cicd_role  = "arn:aws:iam::136115413227:role/eks-cicd"
      # development_cluster_ca_cert    = data.aws_eks_cluster.eks_dev.certificate_authority.0.data

      # production_cluster_name       = local.production_eks_cluster_name
      # production_cluster_api_server = data.aws_eks_cluster.eks_prod.endpoint
      # production_cluster_cicd_role  = "arn:aws:iam::466115813883:role/eks-cicd"
      # production_cluster_ca_cert    = data.aws_eks_cluster.eks_prod.certificate_authority.0.data

      # service account irsa (iam role for service account)
      service_account_name                        = local.argocd_service_account_name
      service_account_annotation                  = "{eks.amazonaws.com/role-arn: ${aws_iam_role.argo_cicd.arn}}"
      application_controller_service_account_name = local.argocd_application_controller_service_account_name

      # repo config

      github_org_url             = local.github_org_url
      github_repo_name           = local.github_repo_name
      github_repo_url            = local.github_repo_url
      github_app_id              = local.github_app_id
      github_app_installation_id = local.github_app_installation_id
      github_app_private_key     = local.github_app_private_key
      # github_webhook_secret      = local.github_webhook_secret

      # SSO - Azure OIDC
      # directory_tenant_id            = local.azure_directory_tenant_id
      # group_object_id_systems_team   = local.azure_group_object_ids.systems_team
      # azure_ad_application_client_id = local.azure_ad_application_client_id
      # client_secret                  = local.azure_client_secret
  })]
}



