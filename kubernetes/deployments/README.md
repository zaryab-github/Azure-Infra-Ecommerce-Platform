# kubernetes/deployments — not yet implemented

Populated in **Phase 5 — AKS**. Will hold one `Deployment` manifest per service (`user-service`, `product-service`, `order-service`), each referencing the image pushed to ACR in Phase 4 and reading config from ConfigMaps/Secrets.
