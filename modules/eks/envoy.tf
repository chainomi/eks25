resource "helm_release" "envoy_gateway" {
  name             = "envoy-gateway"
  repository       = "oci://docker.io/envoyproxy"
  chart            = "gateway-helm"
  version          = "v1.6.3"
  namespace        = "envoy-gateway-system"
  create_namespace = true

  values = [<<-EOT
    config:
      envoyGateway:
        gateway:
          controllerName: gateway.envoyproxy.io/gatewayclass-controller
        provider:
          type: Kubernetes
        logging:
          level:
            default: info

    deployment:
      envoyGateway:
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 1024Mi

      replicas: 2

    createNamespace: false
  EOT
  ]

  timeout = 600
}