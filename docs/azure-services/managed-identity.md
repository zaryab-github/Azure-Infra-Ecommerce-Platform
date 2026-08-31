# Managed Identity

## What it is

A Managed Identity is an identity that Azure creates and manages *for a specific Azure resource* — a VM, an AKS pod, a Function, etc. — so that resource can authenticate to other Azure services without any credential (password, key, or certificate) ever being stored anywhere. There are two kinds:

- **User-assigned** — created as its own standalone resource, which can then be attached to one or more other resources. Its lifecycle is independent of any single resource using it.
- **System-assigned** — created and tied to the lifecycle of exactly one resource; deleting that resource deletes the identity too.

## Why this project uses it

This is the single most important pattern for "no stored secrets in code," which the roadmap calls out explicitly for Phase 9 (Key Vault access) but which this project starts practicing from Phase 1:

- **User-assigned identity `id-ecommerce-aks-prod`** (created in Phase 1, `terraform/modules/identity/main.tf`) — reserved for AKS workloads to use starting Phase 5. Created as user-assigned (not system-assigned) specifically because it needs to exist *before* the AKS cluster does, and because AKS's workload-identity pattern expects a standalone identity that pods can be bound to individually.
- **System-assigned identity on the management VM** (Phase 2b, `terraform/modules/management-vm/main.tf`) — tied to that one VM's lifecycle, which is exactly right here: this identity has no purpose outside that VM.

## Where it's wired in

- `terraform/modules/identity/main.tf` → `azurerm_user_assigned_identity.aks_workload`
- `terraform/modules/management-vm/main.tf` → the `identity { type = "SystemAssigned" }` block on `azurerm_linux_virtual_machine.mgmt`, plus the role assignment referencing `azurerm_linux_virtual_machine.mgmt.identity[0].principal_id`

## How it's actually used, concretely

On the management VM: `az login --identity` authenticates the CLI session as that VM's managed identity — no username, password, or client secret typed or stored anywhere on disk. From there, every `az`/`terraform` command runs with exactly the `Contributor`-on-the-resource-group permissions granted in [azure-rbac.md](azure-rbac.md), nothing more.

On AKS from Phase 5 onward: pods will use **Azure AD Workload Identity** (the modern successor to the older "pod-managed identity" / AAD Pod Identity approach) to federate a Kubernetes service account with `id-ecommerce-aks-prod`, so a pod can call `az`/Azure SDKs and get real Azure permissions without a Kubernetes `Secret` holding a credential.

## Why this matters for the "no secrets in code" story

Every credential that exists as a literal value somewhere (an env var, a config file, a `.tfvars`) is a credential that can leak — checked into git by accident, exposed in a log, copied to the wrong place. Managed identity removes the credential from the picture entirely: the *proof of identity* is "this specific Azure resource is making this specific API call," verified by the platform itself, not by a secret the resource happens to be holding.
