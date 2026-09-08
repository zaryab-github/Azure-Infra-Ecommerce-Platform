# Azure Container Registry

Built in **Phase 4** (`terraform/modules/acr`). See [`docs/deployment_phases/phase-04-acr.md`](../deployment_phases/phase-04-acr.md) for setup steps.

## What it is

A private Docker registry — `acrecommerceprod`, Basic SKU, `admin_enabled = false`. AKS pulls the three service images from it rather than a public registry.

## Why this project uses it

Demonstrates registry-level access control, not just "make the images public": pulls are authorized via `AcrPull` granted to AKS's kubelet identity (an RBAC role assignment living in the **aks** module, Phase 5, since that identity doesn't exist until the cluster is created) — see [azure-rbac.md](azure-rbac.md) and [managed-identity.md](managed-identity.md). No admin username/password anywhere.

## Where it's wired in

`terraform/modules/acr/main.tf` → `azurerm_container_registry.main`. Consumed by `terraform/modules/aks/main.tf` (`azurerm_role_assignment.aks_acr_pull`) and pushed to from the management VM (`az acr login` + `docker push`, Phase 4) or from `pipelines/ci.yml` (Phase 10).
