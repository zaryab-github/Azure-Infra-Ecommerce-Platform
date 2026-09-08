# Azure Policy & Microsoft Defender for Cloud

Built in **Phase 12** (`terraform/modules/security`). See [`docs/deployment_phases/phase-12-security.md`](../deployment_phases/phase-12-security.md) for setup steps.

## What it is

Two built-in Azure Policy assignments scoped to `rg-ecommerce-prod` (**Require a tag on resources** — enforcing the `project` tag; **Allowed locations** — restricting to the one region this project deploys into), plus Microsoft Defender for Cloud pricing tiers for VMs, SQL Servers, Key Vaults, and Containers.

## Why this project uses it

Earlier phases build things *correctly*, but nothing before this continuously checks that they *stay* correct as more gets added — this is ongoing governance, not one-time setup.

## Where it's wired in

`terraform/modules/security/main.tf` — looks up the built-in policy definitions by display name (`data "azurerm_policy_definition_built_in"`, more robust than hardcoding a GUID from memory) rather than pinning a version, and `azurerm_resource_group_policy_assignment` for each. Defender pricing (`azurerm_security_center_subscription_pricing`) is **subscription-wide**, not resource-group scoped — unlike everything else in this project, it doesn't have an RG-level boundary. Kept at the **Free** tier by default (`var.defender_tier`) — switch to `"Standard"` only if you want the paid trial and understand the cost, per [`docs/cost-management.md`](../cost-management.md).
