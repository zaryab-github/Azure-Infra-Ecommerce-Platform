# acr module

Built in **Phase 4 — Azure Container Registry** (see [`docs/ROADMAP.md`](../../../docs/ROADMAP.md), [`docs/deployment_phases/phase-04-acr.md`](../../../docs/deployment_phases/phase-04-acr.md)).

Provisions: Azure Container Registry (Basic tier, `admin_enabled = false`). The AcrPull role assignment for AKS's kubelet identity lives in the **aks** module instead, since that identity doesn't exist until Phase 5.
