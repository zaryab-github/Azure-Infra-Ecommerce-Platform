# sql module

Built in **Phase 6 — Databases** (see [`docs/ROADMAP.md`](../../../docs/ROADMAP.md), [`docs/deployment_phases/phase-06-databases.md`](../../../docs/deployment_phases/phase-06-databases.md)).

Provisions: Azure SQL logical server + Serverless database (auto-pauses on idle), private endpoint into `snet-data`. Tables (`Users`/`Products`/`Orders`) are created and seeded by each service on startup, not by Terraform — see `Application_services/*/src/db.js`. Cosmos DB was never added — not needed at this project's scale.
