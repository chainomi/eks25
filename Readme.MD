

# Commands

1. Plan eks cluster - `make plan service=eks`
2. Apply eks cluster - `make apply service=eks`
3. Destroy eks cluster - `make destroy service=eks`
4. Update kube config - `make eks-auth service=eks`

# Notes
1. Need to enable pod identity agent on main eks module otherwise karpenter controller will go into a crash loop trying to retrieve permissions for AWS services

# References
1. Karpenter module example - https://github.com/timurgaleev/eks-nim-llm-openai/blob/main/main.tf 

# Testing Karpenter
This wont work with deployments that do not have cpu or memory limits set. The deployment in `inflate.yml` has a cpu limit set to 1, which will trigger a karpenter when its scaled
1. From cd into `environments\development\eks` and run `kubectl apply -f inflate.yml`
2. Increase replicas to 5 or 10.

### issues:
1. bottlerocket ami used in nodeclsss has issues with certain applications due to the platform - arm64. Replace with amazon linux
      ```amiSelectorTerms:
        - alias: bottlerocket@latest```  

# Istio Install
1. Deployed with eks cluster using the eks blueprints addons terraform module
2. Configure security groups for istio in the eks module for ports `15017` & `15012`
3. The service type on the istio-ingress should be set to `NodePort` or `ClusterIP`?
4. A rollout restart is required for the istio ingress deployment after istio is deployed using terraform via helm provider as noted here - https://github.com/aws-ia/terraform-aws-eks-blueprints/blob/main/patterns/istio/README.md#deploy
5. Run the command - `kubectl rollout restart deployment istio-ingress -n istio-ingress`
6. Gateway port has to match one of the ports in istio ingress service (deployed via helm chart). ingress service creates target groups for ports 80, 443 & 1501

## Sidecar injection
1. Can be done using labels on namespace
   1. enable sidecare injection - `kubectl label namespace default istio-injection=enabled`
   2. disable sidecar injection - `kubectl label namespace default istio-injection=disable`
   3. use `--overwrite` flag if you see an error - e.g. `kubectl label namespace default istio-injection=enabled --overwrite`
2. Can also be done using labels on the pod or deployment 
   1. 

## Routing traffic via AlB through istio as backend
1. Create an ingress in the same namespace as the istio-ingress 
2. Set the backend to point to the istio-ingress service on desired port e.g. 80
3. Create a gateway and virtual service
4. Set the selector on the gateway to the label used on the istio ingress chart value - e.g. istio: ingressgateway. This can be found in the eks blue prints module under istio-ingress
5. Set the virtual service to point to the target service and port in the cluster
6. Traffic routing should be -  alb --> target group --> istio ingress service --> Istio gateway --> Istio virtual service --> target application service