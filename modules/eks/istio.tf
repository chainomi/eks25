locals {
  istio_chart_url     = "https://istio-release.storage.googleapis.com/charts"
  # istio_chart_version = "1.26.0"
  istio_chart_version = "1.23.0"  
  istio_namespace     = "istio-system"
}

resource "kubectl_manifest" "istio_namespace" {
  yaml_body = <<YAML
apiVersion: v1
kind: Namespace
metadata:
  name: ${local.istio_namespace}
YAML
}


resource "helm_release" "istio-base" {
  name             = "istio-base"
  repository       = local.istio_chart_url
  chart            = "base"
  version          = local.istio_chart_version
  namespace        = local.istio_namespace
  create_namespace = true
}

resource "helm_release" "istiod" {
  name             = "istiod"
  repository       = local.istio_chart_url
  chart            = "istiod"
  version          = local.istio_chart_version
  namespace        = local.istio_namespace
  create_namespace = true

  set {
    name  = "meshConfig.accessLogFile"
    value = "/dev/stdout"
  }
  depends_on = [helm_release.istio-base]
}

# resource "time_sleep" "wait_1_mi" {
#   depends_on = [null_resource.previous]

#   create_duration = "30s"
# }

resource "helm_release" "istio-ingress" {
  name             = "istio-ingress"
  repository       = local.istio_chart_url
  chart            = "gateway"
  version          = local.istio_chart_version
  namespace        = "istio-ingress" # per https://github.com/istio/istio/blob/master/manifests/charts/gateways/istio-ingress/values.yaml#L2
  create_namespace = true

  values = [
    yamlencode(
      {
        labels = {
          istio = "ingressgateway"
        }
        service = {
          type = "ClusterIP"
          annotations = {
            # "service.beta.kubernetes.io/aws-load-balancer-type"            = "nlb-ip"
            # # "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
            # # "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internet-facing"
            # # "service.beta.kubernetes.io/aws-load-balancer-attributes"      = "load_balancing.cross_zone.enabled=true"
            # "service.beta.kubernetes.io/aws-load-balancer-name" = "istio-ingress-internal-lb"            
            # "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
            # "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internal"
            # "service.beta.kubernetes.io/aws-load-balancer-attributes"      = "load_balancing.cross_zone.enabled=true"            
          }
        }
      }
    )
  ]
  # This dependency is needed to solve an issue with the istio ingressgateway deployment needing a restart after istio base and istiod are running
  # https://github.com/aws-ia/terraform-aws-eks-blueprints/blob/main/patterns/istio/README.md#deploy 
  depends_on = [helm_release.istio-base, helm_release.istiod] 
}
