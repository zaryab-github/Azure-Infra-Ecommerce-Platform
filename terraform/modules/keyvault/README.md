# keyvault module — not yet implemented

Built in **Phase 9 — Secrets** (see [`docs/ROADMAP.md`](../../../docs/ROADMAP.md)).

Will provision: Azure Key Vault, access policies / RBAC for the AKS managed identity from the `identity` module, and secrets for the DB password, JWT secret, storage key, and API keys. AKS will read these via workload identity, not by storing credentials in code.
