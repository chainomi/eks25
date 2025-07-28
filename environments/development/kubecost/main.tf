locals {
  region       = "us-west-1"
  environment  = "development"
  cluster_name = "development-eks"
  app_name     = "kubecost"

  kubecost_namespace     = "kubecost"
  kubecost_chart_version = "2.7.2" # adjust this to the version you want to use
  kubecost_domain        = "kubecost.chainomi.link"
  persistent_volume = {
    storage_size       = "32Gi"
    storage_class_name = "kubecost-sc"
    ebs_volume_type    = "gp3"
    filesystem_type    = "ext4"
  }
  alb_cert_arn         = "arn:aws:acm:us-west-1:488144151286:certificate/b1c9bf2e-31c3-4cd9-83de-d09fae059f7a"
  alb_success_codes    = "200,302"
  kubecost_secret_name = "kubecost"
  #   kubecost_token = jsondecode(data.aws_secretsmanager_secret_version.kubecost_current.secret_string)["token"]
}


resource "helm_release" "kubecost" {
  name       = "kubecost"
  repository = "https://kubecost.github.io/cost-analyzer"
  chart      = "cost-analyzer"
  version    = local.kubecost_chart_version
  namespace  = local.kubecost_namespace

  create_namespace = true

  values = [templatefile("./helm/values.yaml",
    {
      app_name = local.app_name
      #   service_account_name       = local.atlantis_service_account.name
      #   service_account_annotation = local.atlantis_service_account.annotation
      alb_cert_arn      = local.alb_cert_arn
      alb_success_codes = local.alb_success_codes
      kubecost_domain   = local.kubecost_domain
      #   kubecost_token             = local.kubecost_token
      storage_class_name = local.persistent_volume.storage_class_name
      storage_size       = local.persistent_volume.storage_size
  })]

  depends_on = [kubectl_manifest.kubecost_persistent_volume]
}

resource "kubectl_manifest" "kubecost_persistent_volume" {
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
