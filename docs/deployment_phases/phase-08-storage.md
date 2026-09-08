# Phase 8 — Storage

Goal: an object storage layer distinct from the relational data in SQL — product images (public-read), invoices and logs (private, reserved for future use).

> **Where this runs**: from the management VM.

## What gets created

| Resource | Purpose |
|---|---|
| `azurerm_storage_account` (Standard LRS) | The account |
| Container `product-images` (container-level public read) | Served by plain URL — no SDK/RBAC code needed in `product-service` |
| Containers `invoices`, `logs` (private) | Reserved — no service reads/writes them yet in this minimal pass |

See [`docs/azure-services/azure-storage-account.md`](../azure-services/azure-storage-account.md).

## Track A — Terraform

```bash
terraform -chdir=terraform/environments/prod plan -target=module.storage
terraform -chdir=terraform/environments/prod apply -target=module.storage
```

## Track B — Azure Portal

1. Inside `rg-ecommerce-prod` → **+ Create a resource** → **Storage account** → globally-unique name (e.g. `stecommerceprod1234`), Standard/LRS.
2. **Containers** → **+ Container** × 3: `product-images` (public access level **Container**), `invoices` (Private), `logs` (Private).

## Wire it into the cluster

Not a secret — just a plain URL, set directly:

```bash
BLOB_URL=$(terraform -chdir=terraform/environments/prod output -raw storage_account_name | xargs -I{} echo "https://{}.blob.core.windows.net/")
sed -i "s#<STORAGE_BLOB_ENDPOINT>#$BLOB_URL#g" kubernetes/deployments/product-service.yaml
kubectl apply -f kubernetes/deployments/product-service.yaml
```

Upload a couple of sample images for the seeded products (ids `1` and `2`) so the URLs resolve:

```bash
az storage blob upload --account-name <storage-account-name> --container-name product-images --name 1.jpg --file ./keyboard.jpg --auth-mode login
az storage blob upload --account-name <storage-account-name> --container-name product-images --name 2.jpg --file ./dock.jpg --auth-mode login
```

## Verification

```bash
curl http://<ingress-ip>/api/products/1   # response now includes an imageUrl
curl -I "https://<storage-account-name>.blob.core.windows.net/product-images/1.jpg"   # 200
```

## Cost / Teardown

Negligible at this scale (<$2/mo). See [`docs/cost-management.md`](../cost-management.md).

## Next

Phase 9 — Secrets.
