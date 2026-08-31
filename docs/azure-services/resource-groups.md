# Resource Groups

## What it is

A Resource Group (RG) is Azure's basic container for organizing resources that share a lifecycle — a logical folder, not a network or security boundary by itself. Every resource in Azure belongs to exactly one RG.

## Why this project uses it

Two resource groups exist in this project, deliberately kept separate:

- **`rg-tfstate`** — holds only the Terraform state storage account (created by `scripts/bootstrap-terraform-backend.ps1`, outside Terraform). Kept separate on purpose: it must survive even if the entire application resource group is deleted and recreated, since it holds the record of what Terraform thinks exists.
- **`rg-ecommerce-prod`** — holds everything else: identity resources, networking, the management VM, and (from later phases) AKS, databases, storage, etc. One RG for the whole application at this project's scale keeps `az group delete` a genuine "tear down everything" button during development — a real production environment might split this further (e.g., one RG per environment or per bounded context), but that split isn't worth the complexity here.

## Where it's wired in

Created by `terraform/modules/identity/main.tf` (`azurerm_resource_group.main`), and referenced by name (`module.identity.resource_group_name`) as an input to every other Terraform module in this project — see `terraform/environments/prod/main.tf`.

## Why here, not somewhere else

RG-scoping is also the reason the Terraform service principal and the management VM's managed identity are both granted **Contributor scoped to this one resource group**, not the subscription — see [azure-rbac.md](azure-rbac.md). Keeping everything for this project inside a single, named RG is what makes that narrow scope possible.
