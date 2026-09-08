# Azure SQL Database

Built in **Phase 6** (`terraform/modules/sql`). See [`docs/deployment_phases/phase-06-databases.md`](../deployment_phases/phase-06-databases.md) for setup steps.

## What it is

One logical server (`sql-ecommerce-prod`) + one Serverless database (`sqldb-ecommerce-prod`, `GP_S_Gen5_1`, auto-pauses after 60 idle minutes), reachable only via a private endpoint in `snet-data` — `public_network_access_enabled = false`.

## Why this project uses it

Real persistence for the three services instead of in-memory arrays — `Users`, `Products`, `Orders` tables, each owned and created by its respective service on startup (see [`docs/services.md`](../services.md)).

## Where it's wired in

`terraform/modules/sql/main.tf` — `azurerm_mssql_server`, `azurerm_mssql_database`, plus `azurerm_private_endpoint` + `azurerm_private_dns_zone` (`privatelink.database.windows.net`) linked to the VNet. The admin password is a Terraform-generated `random_password`, surfaced as a sensitive output — moved into Key Vault in Phase 9, but a plain Kubernetes Secret in the interim (Phase 6's own doc). Each service's `src/db.js` connects with the `mssql` npm package and falls back to an in-memory array when `SQL_SERVER` isn't set.

## Cost note

Serverless auto-pause means near-zero cost when idle — the whole reason this tier was chosen over Basic. See [`docs/cost-management.md`](../cost-management.md).
