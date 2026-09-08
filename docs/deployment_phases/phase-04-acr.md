# Phase 4 — Azure Container Registry

Goal: a private registry for the three service images, pulled by AKS via RBAC (no admin username/password).

> **Where this runs**: from the management VM (Phase 2b) — see `docs/00-prerequisites.md` §0.

## What gets created

| Resource | Purpose |
|---|---|
| `azurerm_container_registry` (Basic, `admin_enabled = false`) | Private image registry |

The AcrPull role assignment for AKS's kubelet identity lives in the **aks** module (Phase 5), not here — that identity doesn't exist until the cluster is created. See [`docs/azure-services/azure-container-registry.md`](../azure-services/azure-container-registry.md).

## Track A — Terraform

```bash
terraform -chdir=terraform/environments/prod plan -target=module.acr
terraform -chdir=terraform/environments/prod apply -target=module.acr
terraform -chdir=terraform/environments/prod output acr_login_server
```

## Track B — Azure Portal

1. Inside `rg-ecommerce-prod` → **+ Create a resource** → **Container Registry**.
2. Name `acrecommerceprod` (must be globally unique — append digits if taken), SKU **Basic**.
3. **Access keys** blade → confirm **Admin user** is **Disabled** (this project uses RBAC, not admin credentials).

## Build and push the three images

From the management VM, once `docker` and `az` are available (cloud-init already installed both):

```bash
az acr login --name <acr-name>

for svc in user-service product-service order-service; do
  docker build -t <acr-login-server>/$svc:latest Application_services/$svc
  docker push <acr-login-server>/$svc:latest
done
```

## Verification

```bash
az acr repository list --name <acr-name> --output table
```

Should list `user-service`, `product-service`, `order-service` once pushed.

## Cost / Teardown

ACR Basic is ~$5/mo flat, no idle-stop option. See [`docs/cost-management.md`](../cost-management.md) — delete via `terraform destroy -target=module.acr` for an extended pause, `terraform apply` recreates it (you'll need to re-push images afterward).

## Next

Phase 5 — AKS, which pulls these images.
