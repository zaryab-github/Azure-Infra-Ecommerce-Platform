# keyvault module

Built in **Phase 9 — Secrets** (see [`docs/ROADMAP.md`](../../../docs/ROADMAP.md), [`docs/deployment_phases/phase-09-secrets.md`](../../../docs/deployment_phases/phase-09-secrets.md)).

Provisions: an RBAC-authorized Key Vault, secrets for the SQL password/connection string, Service Bus connection string, and a reserved JWT secret. AKS reads these via the CSI Secrets Store provider add-on (Phase 5) and a `SecretProviderClass`, not any SDK code in the services — see [`docs/azure-services/azure-key-vault.md`](../../../docs/azure-services/azure-key-vault.md).
