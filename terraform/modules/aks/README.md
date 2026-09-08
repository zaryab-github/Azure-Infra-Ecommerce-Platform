# aks module

Built in **Phase 5 — AKS** (see [`docs/ROADMAP.md`](../../../docs/ROADMAP.md), [`docs/deployment_phases/phase-05-aks.md`](../../../docs/deployment_phases/phase-05-aks.md)).

Provisions: the AKS cluster in `snet-aks`, AcrPull for its kubelet identity, OIDC issuer + workload identity federation with `id-ecommerce-aks-prod`, the Key Vault Secrets Provider add-on, and the Web Application Routing (ingress) add-on. See [`docs/azure-services/azure-kubernetes-service.md`](../../../docs/azure-services/azure-kubernetes-service.md).
