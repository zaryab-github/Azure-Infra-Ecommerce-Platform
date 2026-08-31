# Azure Key Vault — not yet implemented

Lands in **Phase 9** (see [`docs/ROADMAP.md`](../ROADMAP.md), Terraform module `terraform/modules/keyvault`).

**What it will be**: a Key Vault holding the DB password, JWT secret, storage key, and any API keys, read by AKS pods via their managed identity rather than environment variables with literal values.

**Why it's needed here**: this is the payoff of setting up managed identity all the way back in Phase 1 (see [managed-identity.md](managed-identity.md)) — it's what makes "no secrets in code or config" concretely true for the running application, not just for the infrastructure tooling.

This file will be filled in with the actual secret list and the pod-level access pattern (CSI Secrets Store driver vs. SDK calls) once Phase 9 is built.
