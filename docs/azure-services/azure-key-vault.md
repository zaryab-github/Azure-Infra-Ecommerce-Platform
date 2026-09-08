# Azure Key Vault

Built in **Phase 9** (`terraform/modules/keyvault`). See [`docs/deployment_phases/phase-09-secrets.md`](../deployment_phases/phase-09-secrets.md) for setup steps and an important RBAC-propagation caveat.

## What it is

An RBAC-authorized vault (`kv-ecommerce-prod`) — not the older access-policy model — holding `sql-admin-password`, `sql-connection-string`, `servicebus-connection-string`, and a reserved `jwt-secret`.

## Why this project uses it

This is the payoff of setting up managed identity all the way back in Phase 1 (see [managed-identity.md](managed-identity.md)): AKS pods read these secrets via the CSI Secrets Store provider add-on (Phase 5) and a `SecretProviderClass` (`kubernetes/secrets/secretproviderclass.yaml`), which syncs them into a plain Kubernetes Secret the Deployments already reference — **no Key Vault SDK code exists in the services at all**. This supersedes the manual `kubectl create secret` steps from Phases 6/7.

## Where it's wired in

`terraform/modules/keyvault/main.tf` — the vault, 4 secrets, and 3 role assignments: `Key Vault Secrets User` for AKS's CSI provider identity (read-only, what pods need), `Key Vault Secrets Officer` for the management VM's identity and the deploying identity itself (write access, needed to create the secrets in the first place — see the phase doc's RBAC-propagation caveat).
