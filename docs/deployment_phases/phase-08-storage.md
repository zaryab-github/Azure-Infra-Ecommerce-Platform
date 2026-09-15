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

## Part 1 — Wire it into the cluster (Terraform-built storage account)

Not a secret — just a plain URL, set directly:

```bash
BLOB_URL=$(terraform -chdir=terraform/environments/prod output -raw storage_account_name | xargs -I{} echo "https://{}.blob.core.windows.net/")
sed -i "s#<STORAGE_BLOB_ENDPOINT>#$BLOB_URL#g" kubernetes/deployments/product-service.yaml
kubectl apply -f kubernetes/deployments/product-service.yaml
```

## Part 2 — Wire it in for a Portal-built storage account (recommended path)

**2.1 — Get the real blob endpoint**: Portal → your storage account → **Overview** → **Primary endpoint** under **Blob service** (or just build it yourself: `https://<your-storage-account-name>.blob.core.windows.net/`).

**2.2 — Add `STORAGE_ACCOUNT_URL` to `product-service`'s Deployment.** This is a plain, non-secret value (just a URL), so it doesn't go in `app-secrets.yaml` — it's an ordinary env var. If you already removed this placeholder earlier (e.g. while fixing the Phase 5/6 `CrashLoopBackOff` issue — see [`docs/aks/troubleshooting.md`](../aks/troubleshooting.md)), `sed` may not find anything to replace; `kubectl set env` is the reliable way to add it regardless of the file's current placeholder state:

```bash
kubectl set env deployment/product-service -n ecommerce \
  STORAGE_ACCOUNT_URL="https://<your-storage-account-name>.blob.core.windows.net/"
```

Then, so the *file* matches what's now live and a future `kubectl apply` doesn't silently remove it again (see the "old-pod-blocks-new-pod deadlock" note in Phase 6 if pods don't come back up cleanly after this), also add the same line to `kubernetes/deployments/product-service.yaml`'s `env:` block by hand (`nano`), or edit it locally and sync it over — the same lesson from Phase 6 about `sed` being unreliable applies here too.

**Either track — upload sample images** for the seeded products (ids `1` and `2`) so the URLs actually resolve to something:

```bash
az storage blob upload --account-name <storage-account-name> --container-name product-images --name 1.jpg --file ./keyboard.jpg --auth-mode login
az storage blob upload --account-name <storage-account-name> --container-name product-images --name 2.jpg --file ./dock.jpg --auth-mode login
```

## Verification

```bash
curl http://<ingress-ip>/api/products/1   # response now includes an imageUrl
curl -I "https://<storage-account-name>.blob.core.windows.net/product-images/1.jpg"   # 200
```

If `imageUrl` appears in the JSON and the direct blob URL returns `200`, the storage wiring is confirmed end-to-end.

## Cost / Teardown

Negligible at this scale (<$2/mo). See [`docs/cost-management.md`](../cost-management.md).

## Next

Phase 9 — Secrets.
