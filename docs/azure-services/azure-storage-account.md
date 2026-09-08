# Azure Storage Account

Built in **Phase 8** (`terraform/modules/storage`). See [`docs/deployment_phases/phase-08-storage.md`](../deployment_phases/phase-08-storage.md) for setup steps.

## What it is

One Standard LRS account with three containers: `product-images` (container-level **public read**), `invoices` and `logs` (private, reserved — no service reads/writes them yet).

## Why this project uses it

An object-storage layer distinct from the relational data in Azure SQL — and `product-images` being public-read is a deliberate simplification: product photos are meant to be public anyway, so `product-service` can link to them by plain URL with **no SDK or RBAC code needed** in the app, keeping the "very short application code" goal intact.

## Where it's wired in

`terraform/modules/storage/main.tf` — `azurerm_storage_account` + 3 `azurerm_storage_container` resources. `product-service`'s `STORAGE_ACCOUNT_URL` env var (set from the `storage_product_images_url` Terraform output) is all that's needed — see `Application_services/product-service/src/index.js`'s `withImageUrl()`.
