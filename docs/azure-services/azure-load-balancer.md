# Azure Load Balancer

Built implicitly in **Phase 5** — a byproduct of AKS provisioning, not a standalone Terraform resource.

## What it is

AKS automatically provisions a Standard Load Balancer to front `LoadBalancer`-type Kubernetes Services — concretely, the Web Application Routing add-on's nginx ingress controller Service (`nginx` in the `app-routing-system` namespace) gets its public IP from this load balancer.

## Why this project uses it

It's the layer-4 load balancer sitting between Application Gateway (Phase 12) and the AKS ingress controller in the architecture diagram (see [`docs/ROADMAP.md`](../ROADMAP.md#reference-architecture)).

## Where it's wired in

Nowhere explicit in Terraform — it's created automatically by AKS the moment a `LoadBalancer`-type Service exists in the cluster. Find its IP with `kubectl get svc -n app-routing-system nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`, which is exactly the value Phase 12 needs for Application Gateway's backend pool.
