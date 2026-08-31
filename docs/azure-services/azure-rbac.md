# Azure RBAC (Role-Based Access Control)

## What it is

Azure RBAC controls *who can do what, on which resources*. A **role assignment** binds three things together: a **security principal** (a user, group, service principal, or managed identity), a **role definition** (a named bundle of permissions, e.g. `Contributor`, `Reader`, `AcrPull`), and a **scope** (subscription, resource group, or individual resource — permissions granted at a broader scope are inherited by everything underneath it).

## Why this project uses it

Two identities need permissions in this project, and both are deliberately scoped as narrowly as the role system allows:

| Principal | Role | Scope | Why this scope |
|---|---|---|---|
| Terraform service principal (`sp-ecommerce-terraform-prod`) | `Contributor` | `rg-ecommerce-prod` (the resource group) | Not the subscription — this identity's whole job is managing this project's resources, so it shouldn't be able to touch anything else in the subscription |
| Management VM's managed identity | `Contributor` | `rg-ecommerce-prod` (the resource group) | Same reasoning — the VM runs Terraform/az/kubectl for this project only |

Both use the built-in `Contributor` role rather than `Owner`, since neither identity needs to manage *access* to the resource group (grant other principals permissions) — just to manage the resources inside it. Future phases add narrower roles for narrower jobs — e.g. AKS's managed identity will get `AcrPull` (Phase 4) rather than `Contributor`, since pulling container images is all it needs to do.

## Where it's wired in

- `terraform/modules/identity/main.tf` → `azurerm_role_assignment.terraform_contributor`
- `terraform/modules/management-vm/main.tf` → `azurerm_role_assignment.mgmt_contributor`

## The principle this demonstrates

Least privilege: grant the smallest role, at the smallest scope, that lets an identity do its actual job — never subscription-wide `Owner` out of convenience. Every role assignment added in later phases (ACR pull access for AKS, Key Vault access for pods, etc.) should be checked against this same question: *what is the narrowest role and scope that actually works here?*
