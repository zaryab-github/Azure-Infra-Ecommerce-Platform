# Azure SQL Database — not yet implemented

Lands in **Phase 6** (see [`docs/ROADMAP.md`](../ROADMAP.md), Terraform module `terraform/modules/sql`).

**What it will be**: a single Azure SQL logical server + database (Basic or Serverless tier — Serverless preferred so it auto-pauses on idle, see [`docs/cost-management.md`](../cost-management.md)) with `Users`, `Products`, and `Orders` tables, reached from `snet-aks` via a private endpoint in `snet-data`.

**Why it's needed here**: gives each of the three services real persistence instead of the in-memory arrays they use today — see [`docs/services.md`](../services.md) for how each service will own its own tables.

This file will be filled in with the actual schema, connection approach, and private endpoint notes once Phase 6 is built.
