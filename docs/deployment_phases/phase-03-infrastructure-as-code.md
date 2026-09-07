# Phase 3 — Infrastructure as Code

Goal: formalize the convention every phase from here on follows — **everything is Terraform, no Portal clicks required**. Phases 1/2/2b included a manual Portal track as a parallel *learning* path (so you could see each resource created by hand), but that was always optional; from Phase 4 onward, the Portal track in each phase doc exists for the same reason, but the actual deployment is Terraform-only. This phase doesn't create new Azure resources — it's a checkpoint that codifies the module structure and workflow already in use since Phase 1, so later phases can just say "add a module" without re-explaining the pattern.

> **Where this runs**: from the management VM (Phase 2b), per `docs/00-prerequisites.md` §0.

## Module structure

One module per Azure concern, under `terraform/modules/`, each with the same three files (`main.tf`, `variables.tf`, `outputs.tf`):

| Module | Status | Populated in |
|---|---|---|
| `identity` | ✅ Built | Phase 1 |
| `network` | ✅ Built | Phase 2 |
| `management-vm` | ✅ Built | Phase 2b |
| `acr` | ⬜ Placeholder (`README.md` only) | Phase 4 |
| `aks` | ⬜ Placeholder | Phase 5 |
| `sql` | ⬜ Placeholder | Phase 6 |
| `servicebus` | ⬜ Placeholder | Phase 7 |
| `storage` | ⬜ Placeholder | Phase 8 |
| `keyvault` | ⬜ Placeholder | Phase 9 |
| `monitoring` | ⬜ Placeholder | Phase 11 |

Each placeholder's `README.md` states which phase populates it — check the module directory before assuming something doesn't exist yet.

## Root module (the environment)

`terraform/environments/prod/` is the single root module wiring every child module together for this project's one environment:

- `providers.tf` — `azurerm` + `azuread` provider blocks, pinned versions
- `backend.tf` — empty `azurerm` backend block; values supplied via `-backend-config` at `init` time, pointing at the state storage bootstrapped in Phase 1
- `main.tf` — instantiates each module, wiring outputs from one (e.g. `module.identity.resource_group_name`) into inputs of the next
- `variables.tf` / `terraform.tfvars.example` — every input, with a real (gitignored) `terraform.tfvars` holding your actual values
- `outputs.tf` — the values worth surfacing after `apply` (resource group name, subnet IDs, VM IP, etc.)

A single environment (`prod`) is deliberate at this project's scale — see the README for why "prod" rather than "dev": this *is* the production environment, not a throwaway sandbox with a separate real environment elsewhere. If a second environment is ever needed, it's a new sibling directory (`terraform/environments/staging/`) reusing the exact same modules with different variable values — the module/environment split is what makes that cheap.

## Conventions every module follows

- **Naming**: `<resource-type-abbrev>-<project_name>-<role>-<environment>`, e.g. `rg-ecommerce-prod`, `vnet-ecommerce-prod`, `nsg-ecommerce-mgmt-prod` — consistent enough that a resource's name in the Portal tells you what it is and which project/env it belongs to.
- **Tagging**: every resource takes `var.tags`, threaded down from the root module's `tags` variable — `project` and `managed_by` today, extendable without touching every module.
- **Least privilege**: every role assignment is scoped to the narrowest resource that works (resource group, not subscription — see [`docs/azure-services/azure-rbac.md`](../azure-services/azure-rbac.md)), decided per-module, not as an afterthought.
- **No secrets in `.tf` files**: real values live only in the gitignored `terraform.tfvars`; committed files hold structure and an `.example` with placeholder values.

## Workflow (what "no Portal clicks" means day to day)

- Reinitialized the terraform backend:

terraform -chdir=terraform/environments/prod init -reconfigure \
  -backend-config="resource_group_name=rg-tfstate" \
  -backend-config="storage_account_name=stecommercetfstate1" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=prod.terraform.tfstate"

```bash
terraform -chdir=terraform/environments/prod fmt          # normalize formatting before every commit
terraform -chdir=terraform/environments/prod validate      # syntax/type check, no Azure calls needed
terraform -chdir=terraform/environments/prod plan          # review before applying
terraform -chdir=terraform/environments/prod apply         # apply
```

This is the same cycle used for Phases 1/2/2b and every phase after — the only thing that changes phase to phase is which module gets added to `main.tf` and which resources show up in `plan`.

## Verification

```bash
terraform -chdir=terraform/environments/prod fmt -check
terraform -chdir=terraform/environments/prod validate
```

Both should pass with no changes needed and no errors — this doesn't require Azure credentials, just the Terraform CLI, so it's safe to run anytime (including from a fresh clone before ever running `init`).

## Next

Phase 4 — Azure Container Registry: the first placeholder module gets filled in. See [`docs/ROADMAP.md`](../ROADMAP.md).
