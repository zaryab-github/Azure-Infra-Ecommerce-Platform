# Phase 7 — Messaging

Goal: `order-service` publishes to a queue on order creation; `product-service` consumes it and decrements stock — the async flow from the roadmap's architecture diagram.

> **Where this runs**: from the management VM.

## What gets created

| Resource | Purpose |
|---|---|
| `azurerm_servicebus_namespace` (Basic) | The messaging namespace |
| `azurerm_servicebus_queue` "orders" | Basic tier supports queues only (no topics needed here) |
| Scoped auth rule (Send+Listen, not Manage) | Narrower than the namespace's default root key |

See [`docs/azure-services/azure-service-bus.md`](../azure-services/azure-service-bus.md) and [`docs/services.md`](../services.md) for the full flow.

## Track A — Terraform

```bash
terraform -chdir=terraform/environments/prod plan -target=module.servicebus
terraform -chdir=terraform/environments/prod apply -target=module.servicebus
```

## Track B — Azure Portal

1. Inside `rg-ecommerce-prod` → **+ Create a resource** → **Service Bus** → name `sb-ecommerce-prod`, tier **Basic**.
2. Inside the namespace → **Queues** → **+ Queue** → name `orders`, max delivery count 10.
3. **Shared access policies** → **+ Add** → name `app-send-listen`, permissions **Send** + **Listen** only.

## Part 1 — Wire the connection string in (Terraform-built namespace)

Temporary — Phase 9 replaces this with Key Vault:

```bash
SB_CONN=$(terraform -chdir=terraform/environments/prod output -raw servicebus_connection_string)
kubectl create secret generic app-secrets -n ecommerce \
  --from-literal=SERVICEBUS_CONNECTION_STRING="$SB_CONN" --dry-run=client -o yaml | kubectl apply -f -
kubectl rollout restart deployment -n ecommerce
```

`kubectl create secret` **replaces the whole Secret**, not just the one key — if `app-secrets` already exists from Phase 6 (holding `SQL_PASSWORD`), recreate it with both keys together in one command instead of the line above, or you'll silently wipe out the SQL password:

```bash
kubectl create secret generic app-secrets -n ecommerce \
  --from-literal=SQL_PASSWORD="$SQL_PASSWORD" \
  --from-literal=SERVICEBUS_CONNECTION_STRING="$SB_CONN" \
  --dry-run=client -o yaml | kubectl apply -f -
```

## Part 2 — Wire it in for a Portal-built namespace (recommended path)

If you built the Service Bus namespace through the Portal (Track B) — no Terraform state to pull the connection string from. Use the same YAML-Secret file this project already uses for the SQL password (Phase 6), not a fresh ad-hoc `kubectl create secret` call.

**2.1 — Get the real connection string**: Portal → your Service Bus namespace (`sb-ecommerce-prod`) → **Shared access policies** → click `app-send-listen` → copy the **Primary Connection String**.

**2.2 — Add it to the *existing* `app-secrets.yaml`** (from Phase 6) — don't create a separate file. `kubectl apply` on a Secret replaces the entire object, so the file needs every key it should hold, together:

```bash
nano kubernetes/secrets/app-secrets.yaml
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
  namespace: ecommerce
type: Opaque
stringData:
  SQL_PASSWORD: "your-existing-sql-password"                    # from Phase 6 — keep this line
  SERVICEBUS_CONNECTION_STRING: "your-real-connection-string"    # new
```

```bash
kubectl apply -f kubernetes/secrets/app-secrets.yaml
kubectl rollout restart deployment -n ecommerce
```

**No Deployment YAML edits needed** — unlike `SQL_SERVER`/`SQL_DATABASE`/`SQL_USER` (plain, non-secret values that had to be added individually per Deployment in Phase 6), the Service Bus connection string is entirely a secret, and every Deployment already pulls in *all* keys from `app-secrets` automatically via `envFrom`. Adding the key to the Secret file is enough on its own.

## Verification

```bash
curl -X POST http://<ingress-ip>/api/orders -H "Content-Type: application/json" -d "{\"userId\":1,\"productId\":2,\"quantity\":1}"
kubectl logs -n ecommerce deployment/product-service | grep "OrderCreated received"
curl http://<ingress-ip>/api/products/2   # stock should have dropped from 17 to 16
```

If the log line appears and the stock dropped, the full async chain worked: `order-service` → Service Bus queue → `product-service`'s background receiver → stock decrement.

## Cost / Teardown

Service Bus Basic is low, flat cost — no idle-stop option. See [`docs/cost-management.md`](../cost-management.md).

## Next

Phase 8 — Storage.
