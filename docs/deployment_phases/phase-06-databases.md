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

## Part 1 — Wire the connection into the cluster (Terraform-built database)

Until Key Vault (Phase 9) exists, put the password into a plain Kubernetes Secret by hand — this only works if Terraform actually created the database (so `terraform output` has something to read from):

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













## Part 2 — Wiring it in for a Portal-built database (recommended path, with real troubleshooting)

If you built the SQL Database through the Portal (Track B) — no Terraform state exists to pull from, so `terraform output` doesn't apply to you. This is the YAML-based approach, and it's what actually worked end-to-end in practice, including the mistakes worth knowing about ahead of time.

### 2.1 — Gather the real values

From the SQL Database resource's **Overview** blade (or **Connection strings** — copy the "ADO.NET (SQL authentication)" one, it has everything):

- **Server**: `<your-server-name>.database.windows.net` (e.g. `sql-ecommerce-prod.database.windows.net`)
- **Database**: whatever you named it (e.g. `sqldb-ecommerce-prod`)
- **User**: the admin login you chose during creation (this project used `zaryab`, **not** the `sqladmin` default the Terraform module assumes — whatever you actually typed is what goes here)
- **Password**: whatever you typed into the Password field during creation — the Portal never shows it again, so if you didn't save it, use **Reset password** on the SQL server resource to set a new one rather than trying to recover the old one

### 2.2 — Create the Secret as a YAML file (not a one-off `kubectl create` command)

Consistent with how this repo handles everything else — a committed template with placeholders, a gitignored real copy:

```bash
cp kubernetes/secrets/app-secrets.example.yaml kubernetes/secrets/app-secrets.yaml
nano kubernetes/secrets/app-secrets.yaml   # fill in the real SQL_PASSWORD
kubectl apply -f kubernetes/secrets/app-secrets.yaml
```

`app-secrets.yaml` is gitignored — only `app-secrets.example.yaml` (placeholders) is ever committed. **Never put a real password into a file you intend to commit.**

### 2.3 — Put the real values into the Deployment YAMLs

Edit `kubernetes/deployments/{order,product,user}-service.yaml` directly (via `nano`, or edit the repo on your local machine and `git pull`/`scp` it to the VM) and replace the placeholders in the `env:` block with your real server/database/user values from step 2.1. **Also remove** the `APPLICATIONINSIGHTS_CONNECTION_STRING` (and, in `product-service.yaml`, `STORAGE_ACCOUNT_URL`) entries entirely if Phases 8/11 aren't done yet — see the crash warning below for why leaving them as placeholders is actively dangerous, not just incomplete.

`sed`-based find/replace across these files proved unreliable in practice (silently matched nothing, no error) — editing directly with `nano`, or editing locally where a proper editor/Edit tool is available and syncing to the VM, is the dependable path.

```bash
kubectl apply -f kubernetes/deployments/
kubectl rollout restart deployment -n ecommerce
```

### 2.4 — Three real failure modes worth knowing before you hit them

**A crash-causing "placeholder left set" bug.** A `<PLACEHOLDER_TEXT>` value isn't the same as "not configured" — application code checking `if (process.env.SOME_VAR)` sees any non-empty string as truthy, placeholder or not. This project's `APPLICATIONINSIGHTS_CONNECTION_STRING` guard is exactly this shape — leaving it set to `<APP_INSIGHTS_CONNECTION_STRING>` made the Application Insights SDK try to parse garbage and throw **synchronously at startup**, producing `CrashLoopBackOff` with no HTTP traffic involved at all. General rule: **remove** a not-yet-configured env var entirely rather than leaving it set to placeholder text.

**The old-pod-blocks-new-pod deadlock.** Any change to a Deployment's pod template (`kubectl apply` with edited YAML, or `kubectl set env`) creates a new ReplicaSet — it does not edit existing pods in place. On a capacity-constrained single node, the old pod can keep occupying the exact room the new one needs, and Kubernetes won't retire the old one until the new one is healthy — a genuine deadlock. Diagnose with `kubectl get pods -n ecommerce` (look for two ReplicaSet hashes per service); resolve with `kubectl delete rs <old-replicaset-name> -n ecommerce` to free the room. See [`docs/aks/troubleshooting.md`](../aks/troubleshooting.md).

**"Login failed for user" means the Secret is missing, not that the password is wrong.** Every Deployment references `app-secrets` via `envFrom: secretRef: ..., optional: true` — that `optional: true` means if the Secret doesn't exist at all, Kubernetes doesn't error, it just silently omits `SQL_PASSWORD` from the pod's environment. The app then connects with a blank password, and SQL Server correctly reports `Login failed for user '<name>'` — indistinguishable at a glance from an actually-wrong password. Always check the Secret exists first: `kubectl get secret app-secrets -n ecommerce` (a `NotFound` error means step 2.2 was never actually applied) before assuming the password itself is wrong.

## Verification

```bash
kubectl get secret app-secrets -n ecommerce                                    # confirm it exists at all
kubectl get pods -n ecommerce -o wide                                          # one Running pod per service, no duplicates
kubectl logs -n ecommerce deployment/user-service | grep -i "listening\|DB init"   # no "DB init failed" line
curl http://<ingress-ip>/api/users   # should now be served from SQL
```

## Cost / Teardown

Serverless auto-pauses on idle — near-zero cost when not actively used. The private endpoint + DNS zone add a small flat cost. See [`docs/cost-management.md`](../cost-management.md). Deleting/recreating this module **loses data** — it's a lab database with seed data only, so that's an acceptable tradeoff here, but wouldn't be for anything real.

## Next

Phase 7 — Messaging.
