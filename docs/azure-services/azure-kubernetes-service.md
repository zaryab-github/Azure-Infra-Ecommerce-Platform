# Azure Kubernetes Service (AKS)

Built in **Phase 5** (`terraform/modules/aks`). See [`docs/deployment_phases/phase-05-aks.md`](../deployment_phases/phase-05-aks.md) for setup steps.

## What it is

The managed Kubernetes cluster (`aks-ecommerce-prod`, `Standard_B2s` × 1 node, Free SKU tier) running the three services, deployed into `snet-aks` (see [virtual-network-and-subnets.md](virtual-network-and-subnets.md)).

## Why this project uses it

The centerpiece of the whole architecture — everything before this phase exists to support it, everything after depends on it being there.

## Where it's wired in and how the pieces fit

`terraform/modules/aks/main.tf`:
- **Networking**: Azure CNI into `snet-aks`, `network_policy = "azure"` (enforced by Phase 12's NetworkPolicy manifests).
- **Identity**: system-assigned control-plane identity; a separate, auto-created **kubelet identity** granted `AcrPull` on ACR (Phase 4); OIDC issuer + workload identity federation binding `id-ecommerce-aks-prod` (Phase 1) to the `ecommerce-workload-sa` ServiceAccount — see [managed-identity.md](managed-identity.md).
- **Add-ons, not manual installs**: the **Key Vault Secrets Provider** (Phase 9's CSI driver) and **Web Application Routing** (the nginx-based ingress controller, Phase 5) are both AKS-managed add-ons enabled directly on the cluster resource — no separate Helm install step.
- **Monitoring**: `oms_agent` block references Phase 11's Log Analytics workspace, gated behind `var.enable_monitoring` so the cluster can be created before that module exists.

## Kubernetes-side resources

`kubernetes/namespace.yaml`, `deployments/`, `services/`, `ingress/`, `hpa/` — one Deployment/Service/HPA per service, an Ingress routing by path prefix. See [`docs/services.md`](../services.md) for what runs inside them.
