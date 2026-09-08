# user-service

Minimal Express API. Its job in this project is to prove connectivity (ACR → AKS → ingress → this pod, and later, this pod → Azure SQL/Key Vault/Service Bus), not to implement real user management.

See [`docs/services.md`](../../docs/services.md) for how this fits with `product-service`/`order-service`, the full communication story, and why it's built this way.

## Current scope

- `GET /health` — liveness/readiness check
- `GET /api/users` / `GET /api/users/:id` — reads from Azure SQL (`Users` table, seeded on first startup) when `SQL_SERVER` is set; otherwise falls back to a static in-memory list, so it still runs standalone with no Azure dependency
- Application Insights auto-instrumentation when `APPLICATIONINSIGHTS_CONNECTION_STRING` is set (Phase 11)

## Deferred / out of scope

- Full CRUD (create/update/delete users) — this project only needs to prove read connectivity, not real user management
- Auth/JWT — no login flow exists; the `jwt-secret` Key Vault entry (Phase 9) is reserved for if that's ever added

## Run locally

```bash
npm install
npm start
curl http://localhost:3001/health
```

## Build the container

```bash
docker build -t user-service:local .
docker run -p 3001:3001 user-service:local
```
