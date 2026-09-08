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

## Wire the connection string in (temporary — Phase 9 replaces this)

```bash
SB_CONN=$(terraform -chdir=terraform/environments/prod output -raw servicebus_connection_string)
kubectl create secret generic app-secrets -n ecommerce \
  --from-literal=SERVICEBUS_CONNECTION_STRING="$SB_CONN" --dry-run=client -o yaml | kubectl apply -f -
kubectl rollout restart deployment -n ecommerce
```

(This merges into the same `app-secrets` Secret Phase 6 created — `kubectl create ... --dry-run=client -o yaml | kubectl apply -f -` is idempotent and additive here since each `--from-literal` targets a different key... actually `kubectl create secret` replaces the whole Secret each time. If you already ran Phase 6's version, recreate it with both keys in one command instead:)

```bash
kubectl create secret generic app-secrets -n ecommerce \
  --from-literal=SQL_PASSWORD="$SQL_PASSWORD" \
  --from-literal=SERVICEBUS_CONNECTION_STRING="$SB_CONN" \
  --dry-run=client -o yaml | kubectl apply -f -
```

## Verification

```bash
curl -X POST http://<ingress-ip>/api/orders -H "Content-Type: application/json" -d '{"userId":1,"productId":2,"quantity":1}'
kubectl logs -n ecommerce deployment/product-service | grep "OrderCreated received"
curl http://<ingress-ip>/api/products/2   # stock should have decremented
```

## Cost / Teardown

Service Bus Basic is low, flat cost — no idle-stop option. See [`docs/cost-management.md`](../cost-management.md).

## Next

Phase 8 — Storage.
