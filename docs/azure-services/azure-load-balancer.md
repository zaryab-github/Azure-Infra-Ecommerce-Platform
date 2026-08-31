# Azure Load Balancer — not yet implemented

Lands in **Phase 5** (see [`docs/ROADMAP.md`](../ROADMAP.md)) as a byproduct of AKS provisioning — AKS creates a Standard Load Balancer automatically to front `LoadBalancer`-type Kubernetes Services and to provide the AKS nodes' outbound path where relevant.

**Why it's needed here**: it's the layer-4 load balancer sitting between Application Gateway and the AKS ingress controller in the architecture diagram (see [`docs/ROADMAP.md`](../ROADMAP.md#reference-architecture)).

This file will be filled in with the actual configuration notes once Phase 5 is built.
