locals {
  argocd_project_name = "argocd-demo"
  argocd_app_name     = "flask-app-demo"
  argocd_destination_server = {
    local = "https://kubernetes.default.svc"
  }
  argocd_app_namespace = "default"
  argocd_app_chart = {
    path        = "flask-api-chart"
    values_file = "values.yaml"
  }
}


resource "kubectl_manifest" "argocd_project" {
  yaml_body = <<YAML
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: ${local.argocd_project_name}
  namespace: ${local.argocd_namespace}
  # Finalizer that ensures that project is not deleted until it is not referenced by any application
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  description:  ${local.argocd_project_name} argocd project
  # Allow manifests to deploy from any Git repos
  sourceRepos:
  - '*'
  # Only permit applications to deploy to the flask-api namespace in the same cluster
  destinations:
  - namespace: '*'
    server: ${local.argocd_destination_server.local}
  clusterResourceWhitelist:
  - group: "*"
    kind: "*"    
YAML
depends_on = [helm_release.argo-cd]
}

resource "kubectl_manifest" "argocd_app" {
  yaml_body  = <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${local.argocd_app_name}
  namespace: ${local.argocd_namespace}
spec:
  project: ${local.argocd_project_name}
  source:
    repoURL: ${local.github_repo_url}
    targetRevision: HEAD
    path: ${local.argocd_app_chart.path}
    helm:
      valueFiles:
      - ${local.argocd_app_chart.values_file}
  destination:
    server: ${local.argocd_destination_server.local}
    namespace: ${local.argocd_app_namespace}
  
  syncPolicy:
    automated: 
      prune: true 
    syncOptions:    
    - CreateNamespace=true 
YAML
  depends_on = [kubectl_manifest.argocd_project]
}


