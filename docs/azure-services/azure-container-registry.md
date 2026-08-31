# Azure Container Registry — not yet implemented

Lands in **Phase 4** (see [`docs/ROADMAP.md`](../ROADMAP.md), Terraform module `terraform/modules/acr`).

**What it will be**: a private Docker registry for this project's three service images, so AKS pulls from a registry you control rather than a public one.

**Why it's needed here**: AKS needs somewhere to pull `user-service`/`product-service`/`order-service` images from. A private registry with `AcrPull` granted narrowly to AKS's managed identity (see [managed-identity.md](managed-identity.md) and [azure-rbac.md](azure-rbac.md)) demonstrates registry-level access control, not just "make the images public."

This file will be filled in with the actual implementation notes once Phase 4 is built.
