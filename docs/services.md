# Services — purpose, implementation, and communication

This is the one place that explains all three demo services together: what each one is *for*, what it actually does today, and how they fit together as a system. Each service also has its own `README.md` (`Application_services/<name>/README.md`) with just its own run/build commands — read this file first for the big picture, then the per-service README for the specifics.

## Why three services, and why these three

The roadmap's architecture diagram splits the application into `user-service`, `product-service`, and `order-service` — a textbook microservices decomposition of an e-commerce domain into its three natural bounded contexts:

- **user-service** — who's placing the order (identity/profile data)
- **product-service** — what's for sale (catalog/inventory data)
- **order-service** — what was bought, by whom, and how many (transactional data that references the other two)

This split exists to give the infrastructure something realistic to demonstrate: independent deployments, independent scaling (an HPA per service in Phase 5), independent data ownership (Phase 6), a service-to-service messaging story (Phase 7), and independent CI/CD pipelines per service (Phase 10) — the same shape a real e-commerce backend would have, just with each service doing the minimum needed to prove the platform works. **The application logic itself is intentionally shallow** — see each service's README for exactly what's stubbed vs. real.

## What each service implements today

All three are Express apps with the same shape: a `/health` endpoint, one or two REST routes, and an in-memory array standing in for a database. None of them call each other or any Azure service yet — that's deliberate, since none of the Azure resources they'd talk to (SQL, Service Bus, Key Vault) exist until Phases 6/7/9.

| Service | Port | Endpoints | Data (today) |
|---|---|---|---|
| `user-service` | 3001 | `GET /health`, `GET /api/users`, `GET /api/users/:id` | Hardcoded array of 2 users |
| `product-service` | 3002 | `GET /health`, `GET /api/products`, `GET /api/products/:id` | Hardcoded array of 2 products |
| `order-service` | 3003 | `GET /health`, `GET /api/orders`, `POST /api/orders` | In-memory array, appended to at runtime (resets on pod restart) |

`/health` exists on every service for one reason: it's what Kubernetes liveness/readiness probes will call starting Phase 5, and what the CI/CD pipeline's smoke test (Phase 10) will call after every deploy. It returns `{ status: "ok", service: "<name>" }` with a 200 — enough for a probe or a pipeline step to decide "this pod is alive," nothing more.

## How they communicate — today vs. planned

**Today: they don't communicate with each other at all.** Each is a fully independent REST API. The only "communication" is external: a client (browser, curl, or later an Ingress) calls one service's HTTP endpoints directly. This is intentional for the current phase — Phases 1/2/2b are pure infrastructure (identity, network, the admin VM), so there's nothing for the services to connect *to* yet.

**From Phase 5 (AKS) on — synchronous, via the ingress:**

```
Client
  -> Application Gateway (WAF)
  -> Azure Load Balancer
  -> AKS Ingress Controller
       -> Service (ClusterIP) "user-service"    -> Pod(s)
       -> Service (ClusterIP) "product-service" -> Pod(s)
       -> Service (ClusterIP) "order-service"   -> Pod(s)
```

Each service gets its own Kubernetes `Service` (stable internal DNS name, e.g. `user-service.default.svc.cluster.local`) and `Deployment` (replica set of pods). The Ingress routes by path (e.g. `/api/users/*` → `user-service`, `/api/products/*` → `product-service`, `/api/orders/*` → `order-service`) to whichever pod is healthy — this is what "Kubernetes service discovery" and "load balancing" concretely mean in this project.

**From Phase 7 (Messaging) on — asynchronous, via Service Bus:** this is the one place the services actually talk to *each other*, not just to clients:

```
Client -> POST /api/orders on order-service
             |
             v
      order-service publishes an "OrderCreated" message
             |
             v
      Azure Service Bus queue "orders"
             |
             v
      An order processor consumes the message
             |
             v
      Calls product-service to decrement stock for the ordered item
```

This exists to demonstrate the roadmap's messaging pattern (decoupled, asynchronous inter-service communication — the order can be accepted immediately without waiting on inventory to update synchronously) rather than because a stock decrement genuinely requires a message queue at this scale. Until Phase 7 lands, `order-service`'s `POST /api/orders` just appends to its in-memory array and returns — there is no queue publish yet, and the code comment in `Application_services/order-service/src/index.js` marks exactly where that will be added.

## Data ownership (planned, Phase 6)

Each service will own its own tables in the shared Azure SQL server from Phase 6 — `user-service` reads/writes `Users`, `product-service` reads/writes `Products`, `order-service` reads/writes `Orders` (with `userId`/`productId` foreign-key-style references, but no cross-service SQL joins — a service only ever queries its own tables, and gets other services' data over HTTP/Service Bus like any other client would). Sharing one SQL *server* across services (rather than one server per service) is a portfolio-scale simplification to stay inside the Azure credit — a real production system would more likely give each service its own database.

## Secrets and identity (planned, Phase 9)

None of the services have any secrets yet — there's nothing to authenticate to. From Phase 9, each service's SQL connection string (and the Service Bus connection string, once Phase 7 lands) will be read from Azure Key Vault at startup via the AKS pod's managed identity (wired in Phase 5, created back in Phase 1) — never from a literal environment variable value or a file checked into the repo.

## Why Node.js/Express, and why this shallow

Express was chosen (see the project's setup discussion) because it's the fastest way to stand up a real, independently deployable HTTP service with minimal code — this project's actual point is everything *around* these services (Terraform, AKS, networking, CI/CD), not the services themselves. Each one is intentionally small enough to read start-to-finish in under a minute; if a piece of application logic ever feels like it's growing past "prove the infrastructure works," that's a signal to stop, not to add more.
