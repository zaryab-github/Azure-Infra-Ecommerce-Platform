# acr module — not yet implemented

Built in **Phase 4 — Azure Container Registry** (see [`docs/ROADMAP.md`](../../../docs/ROADMAP.md)).

Will provision: Azure Container Registry (Basic tier) and an AcrPull role assignment for the AKS managed identity, so the cluster can pull the `user-service` / `product-service` / `order-service` images built from [`Application_services/`](../../../Application_services).
