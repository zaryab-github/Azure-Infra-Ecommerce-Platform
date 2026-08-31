# product-service

Minimal Express API. Its job in this project is to prove connectivity (ACR → AKS → ingress → this pod, and later, this pod → Azure SQL/Storage/Service Bus), not to implement a real catalog.

See [`docs/services.md`](../../docs/services.md) for how this fits with `user-service`/`order-service`, the full communication story, and why it's built this way.

## Current scope

- `GET /health` — liveness/readiness check
- `GET /api/products` — static in-memory list
- `GET /api/products/:id`

## Deferred to later phases

- Azure SQL persistence (Phase 6) instead of the in-memory array
- Product images served from Azure Storage (Phase 8)
- Consuming inventory-update messages from Service Bus, published by `order-service` (Phase 7)

## Run locally

```bash
npm install
npm start
curl http://localhost:3002/health
```

## Build the container

```bash
docker build -t product-service:local .
docker run -p 3002:3002 product-service:local
```
