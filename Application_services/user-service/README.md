# user-service

Minimal Express API. Its job in this project is to prove connectivity (ACR → AKS → ingress → this pod, and later, this pod → Azure SQL/Key Vault/Service Bus), not to implement real user management.

See [`docs/services.md`](../../docs/services.md) for how this fits with `product-service`/`order-service`, the full communication story, and why it's built this way.

## Current scope

- `GET /health` — liveness/readiness check
- `GET /api/users` — static in-memory list
- `GET /api/users/:id`

## Deferred to later phases

- Azure SQL persistence (Phase 6) instead of the in-memory array
- Reading its DB connection string from Key Vault via managed identity (Phase 9), not an env var with a literal secret
- Publishing/consuming Service Bus messages if needed (Phase 7)

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
