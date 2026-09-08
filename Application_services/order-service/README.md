# order-service

Minimal Express API. Its job in this project is to prove connectivity (ACR → AKS → ingress → this pod, and later, this pod → Azure SQL/Service Bus), not to implement a real checkout flow.

See [`docs/services.md`](../../docs/services.md) for how this fits with `user-service`/`product-service`, the full communication story (including the planned Service Bus flow), and why it's built this way.

## Current scope

- `GET /health` — liveness/readiness check
- `GET /api/orders` / `POST /api/orders` — `{ userId, productId, quantity }`, persisted to Azure SQL (`Orders` table) when `SQL_SERVER` is set, else an in-memory list
- On creation, best-effort publishes an `OrderCreated` message to the Service Bus `orders` queue (`src/servicebus.js`) when `SERVICEBUS_CONNECTION_STRING` is set — consumed by `product-service`'s receiver (Phase 7)
- Application Insights auto-instrumentation when `APPLICATIONINSIGHTS_CONNECTION_STRING` is set (Phase 11)

## Deferred / out of scope

- Full order lifecycle (cancellation, payment, fulfillment) — this project only needs to prove the create → publish → consume connectivity

## Run locally

```bash
npm install
npm start
curl http://localhost:3003/health
curl -X POST http://localhost:3003/api/orders -H "Content-Type: application/json" -d "{\"userId\":1,\"productId\":2,\"quantity\":1}"
```

## Build the container

```bash
docker build -t order-service:local .
docker run -p 3003:3003 order-service:local
```
