# Azure Storage Account — not yet implemented

Lands in **Phase 8** (see [`docs/ROADMAP.md`](../ROADMAP.md), Terraform module `terraform/modules/storage`).

**What it will be**: one Storage Account with containers for product images, generated invoices, and exported logs.

**Why it's needed here**: gives the platform an object-storage story distinct from the relational data in Azure SQL — images and documents don't belong in a database table.

This file will be filled in with the actual container layout and access pattern (SAS tokens vs. managed identity) once Phase 8 is built.
