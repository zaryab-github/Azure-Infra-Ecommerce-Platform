# product-service

Minimal Express API. Its job in this project is to prove connectivity (ACR → AKS → ingress → this pod, and later, this pod → Azure SQL/Storage/Service Bus), not to implement a real catalog.

See [`docs/services.md`](../../docs/services.md) for how this fits with `user-service`/`order-service`, the full communication story, and why it's built this way.

## Current scope

- `GET /health` — liveness/readiness check
- `GET /api/products` / `GET /api/products/:id` — reads from Azure SQL (`Products` table, seeded on first startup) when `SQL_SERVER` is set, else an in-memory list; each product's `imageUrl` is a plain URL into the public `product-images` Storage container when `STORAGE_ACCOUNT_URL` is set (Phase 8)
- A background Service Bus receiver (`src/servicebus.js`) consuming the `orders` queue and decrementing stock — this is the "Inventory Service" from the roadmap's messaging diagram, folded into this service rather than a 4th standalone one (Phase 7)
- Application Insights auto-instrumentation when `APPLICATIONINSIGHTS_CONNECTION_STRING` is set (Phase 11)

## Deferred / out of scope

- Full CRUD, image upload — this project only needs to prove read/consume connectivity

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
