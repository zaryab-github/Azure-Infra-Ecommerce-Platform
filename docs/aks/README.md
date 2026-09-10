# AKS — complete reference

This directory is a deep dive into Azure Kubernetes Service itself — not the how-to-provision-it steps (that's [`docs/deployment_phases/phase-05-aks.md`](../deployment_phases/phase-05-aks.md)), but how the thing actually works, day to day, once it exists. Written against *this project's actual cluster* — `aks-ecommerce-prod`, a single `Standard_B2s` node, Cilium dataplane, Web Application Routing ingress, Key Vault Secrets Provider, workload identity — so every command here is one you can run against your own cluster right now, not a generic tutorial.

| File | Covers |
|---|---|
| [cluster-management.md](cluster-management.md) | The control plane vs. node pools, scaling, upgrades, stop/start, node pool sizing, what "managed" actually means |
| [networking.md](networking.md) | Pod IPs vs. Service IPs vs. node IPs, CNI modes, DNS, Ingress, Load Balancer, how traffic actually flows in from the internet |
| [rbac-and-identity.md](rbac-and-identity.md) | Kubernetes RBAC vs. Azure RBAC (two separate systems), ServiceAccounts, workload identity, federated credentials |
| [storage-and-volumes.md](storage-and-volumes.md) | PersistentVolumes/Claims, StorageClasses, the CSI drivers actually running on this cluster, when you need this vs. when you don't |
| [service-mesh.md](service-mesh.md) | What Istio/service mesh is, why this project doesn't use one, and what happened when the Portal wizard enabled it anyway |
| [logging-and-monitoring.md](logging-and-monitoring.md) | `kubectl logs`/`describe` day-to-day, Container Insights, Log Analytics queries, Application Insights, metrics-server/HPA |
| [policies-and-crds.md](policies-and-crds.md) | What a CRD is, every CRD actually on this cluster, Azure Policy for AKS (Gatekeeper/OPA) vs. this project's ARM-level policy |
| [troubleshooting.md](troubleshooting.md) | A practical runbook — the actual errors this project's build hit, why, and the fix, generalized so you recognize the pattern next time |
| [backup-and-disaster-recovery.md](backup-and-disaster-recovery.md) | What Azure already protects for you, what it doesn't, and what a real backup story looks like |

## The one-sentence mental model

AKS gives you a **free, Azure-managed control plane** (API server, etcd, scheduler — you never patch or see these) sitting in front of **node pools you pay for and partially manage** (VMs Azure provisions into your VNet subnet, but you choose size/count and Azure handles OS patching). Everything under `kube-system` and the other system namespaces you saw in `kubectl get all -A` is what Azure and its add-ons run *on your node pool* to make that promise true — DNS, networking, CSI drivers, metrics, whatever add-ons you enabled. That's also why every add-on you enable has a real cost in node capacity, not just cloud billing — see [service-mesh.md](service-mesh.md) for exactly how that bit this project.
