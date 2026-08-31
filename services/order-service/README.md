# order-service

Minimal Express API. Its job in this project is to prove connectivity (ACR → AKS → ingress → this pod, and later, this pod → Azure SQL/Service Bus), not to implement a real checkout flow.

See [`docs/services.md`](../../docs/services.md) for how this fits with `user-service`/`product-service`, the full communication story (including the planned Service Bus flow), and why it's built this way.

## Current scope

- `GET /health` — liveness/readiness check
- `GET /api/orders` — in-memory list
- `POST /api/orders` — `{ userId, productId, quantity }`, appended to the in-memory list

## Deferred to later phases

- Azure SQL persistence (Phase 6) instead of the in-memory array
- Publishing a message to the Service Bus `orders` queue on order creation (Phase 7), consumed by an order processor that updates `product-service` inventory

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
