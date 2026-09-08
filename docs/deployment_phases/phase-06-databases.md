# Phase 6 — Databases

Goal: Azure SQL, reachable only via a private endpoint, holding the `Users`/`Products`/`Orders` tables each service creates and seeds on startup.

> **Where this runs**: from the management VM.

## What gets created

| Resource | Purpose |
|---|---|
| `azurerm_mssql_server` + `azurerm_mssql_database` (Serverless `GP_S_Gen5_1`, auto-pause 60 min) | The database — auto-pauses when idle, near-zero cost |
| Private endpoint in `snet-data` + private DNS zone | No public network access — only reachable from inside the VNet |
| `random_password` admin password | Terraform-generated, surfaced as a sensitive output |

See [`docs/azure-services/azure-sql-database.md`](../azure-services/azure-sql-database.md).

## Track A — Terraform

```bash
terraform -chdir=terraform/environments/prod plan -target=module.sql
terraform -chdir=terraform/environments/prod apply -target=module.sql
```

## Track B — Azure Portal

1. Inside `rg-ecommerce-prod` → **+ Create a resource** → **SQL Database** → **Create new server**: name `sql-ecommerce-prod`, admin login of your choice, generate a strong password (save it — Terraform won't know about a Portal-created password).
2. Database: name `sqldb-ecommerce-prod`, compute tier **Serverless**, min vCores 0.5, auto-pause **60 minutes**.
3. **Networking** tab: **Disable** public network access; add a **Private endpoint** into `snet-data`, integrate with a new/existing private DNS zone `privatelink.database.windows.net`.

## Wire the connection into the cluster (temporary — Phase 9 replaces this)

Until Key Vault (Phase 9) exists, put the password into a plain Kubernetes Secret by hand:

```bash
SQL_PASSWORD=$(terraform -chdir=terraform/environments/prod output -raw sql_admin_password)
kubectl create secret generic app-secrets -n ecommerce \
  --from-literal=SQL_PASSWORD="$SQL_PASSWORD" --dry-run=client -o yaml | kubectl apply -f -

sed -i "s#<SQL_SERVER_FQDN>#$(terraform -chdir=terraform/environments/prod output -raw sql_server_fqdn)#g; \
        s#<SQL_DATABASE_NAME>#sqldb-ecommerce-prod#g; \
        s#<SQL_ADMIN_USERNAME>#sqladmin#g" kubernetes/deployments/*.yaml

kubectl apply -f kubernetes/deployments/
```

Each service creates its table and seeds it on next startup — see `Application_services/*/src/db.js` and `docs/services.md`.

## Verification

```bash
kubectl rollout restart deployment -n ecommerce
kubectl logs -n ecommerce deployment/user-service | grep -i "listening\|DB init"
curl http://<ingress-ip>/api/users   # should now be served from SQL
```

## Cost / Teardown

Serverless auto-pauses on idle — near-zero cost when not actively used. The private endpoint + DNS zone add a small flat cost. See [`docs/cost-management.md`](../cost-management.md). Deleting/recreating this module **loses data** — it's a lab database with seed data only, so that's an acceptable tradeoff here, but wouldn't be for anything real.

## Next

Phase 7 — Messaging.
