# Azure Kubernetes Service (AKS) — not yet implemented

Lands in **Phase 5** (see [`docs/ROADMAP.md`](../ROADMAP.md), Terraform module `terraform/modules/aks`).

**What it will be**: the managed Kubernetes cluster running the three demo services, deployed into `snet-aks` (see [virtual-network-and-subnets.md](virtual-network-and-subnets.md)), using `id-ecommerce-aks-prod` (see [managed-identity.md](managed-identity.md)) for workload identity.

**Why it's needed here**: it's the centerpiece of the whole architecture — the roadmap's entire point is demonstrating a production-style AKS deployment (node pools, ingress, HPA, ConfigMaps/Secrets, workload identity) rather than just "an app running somewhere."

This file will be filled in with the actual implementation notes, node pool sizing rationale, and ingress choice once Phase 5 is built.
