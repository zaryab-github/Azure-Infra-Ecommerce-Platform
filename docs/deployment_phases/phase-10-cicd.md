# Phase 10 — CI/CD

Goal: `git push` to `main` builds, tests (where tests exist), pushes images to ACR, and — after approval — applies Terraform and deploys to AKS automatically, per `pipelines/ci.yml` and `pipelines/cd.yml`.

> **Where this runs**: Azure DevOps itself is a SaaS product, not an ARM resource — there's no `azurerm_*` Terraform resource for "create an Azure DevOps project." (An `azuredevops` Terraform provider exists but isn't used here, to keep scope reasonable.) So unlike every phase before this, **this phase is Portal(Azure DevOps)-primary**, not Terraform-primary. That's a deliberate, honest scope decision, not an oversight.

## What gets created (all via the Azure DevOps Portal, not Terraform)

| Thing | Purpose |
|---|---|
| Azure DevOps organization + project | Where the pipelines live |
| Service Connection `acr-service-connection` (Docker Registry type) | Lets `ci.yml` push to ACR |
| Service Connection `azure-service-connection` (ARM type) | Lets `cd.yml` run Terraform/kubectl against the subscription |
| Pipeline `ci` → `pipelines/ci.yml` | Build/test/push on every push to `main` |
| Pipeline `cd` → `pipelines/cd.yml` | Terraform apply + AKS deploy, manually triggered or gated behind an environment approval |

## Setup (Azure DevOps Portal)

1. [dev.azure.com](https://dev.azure.com) → create an organization (free) → **+ New project** → name it (e.g. `azure-ecommerce-platform`).
2. **Repos** → **Import** → point at this repo's GitHub URL (`https://github.com/zaryab-github/Azure-Infra-Ecommerce-Platform.git`), or connect Pipelines directly to the GitHub repo instead of importing — either works.
3. **Project settings → Service connections** → **New service connection**:
   - **Docker Registry** type → Azure Container Registry → select your subscription and `acrecommerceprod` → name it `acr-service-connection`.
   - **Azure Resource Manager** type → **Workload identity federation (automatic)** (preferred — no stored secret) → select the subscription → name it `azure-service-connection`.
4. **Pipelines** → **New pipeline** → point at `pipelines/ci.yml` → save, name it `ci`. Repeat for `pipelines/cd.yml`, name it `cd`, and set its trigger to manual (already `trigger: none` in the file).
5. **Pipelines → Environments** → **New environment** → name `production` → add an **Approval** check so `cd.yml`'s deploy stages need a human click before running.
6. Set pipeline variables on `cd`: `tfStateResourceGroup` = `rg-tfstate`, `tfStateStorageAccount` = your bootstrap storage account name, `acrLoginServer` = the `acr_login_server` Terraform output.

## Verification

Push a small change (e.g. edit a service's README) to `main` and confirm the `ci` pipeline runs and pushes new image tags to ACR. Manually trigger `cd`, approve the `production` environment gate, and confirm `kubectl get pods -n ecommerce` shows a new rollout.

## Cost / Teardown

Azure DevOps's free tier (1 free Microsoft-hosted parallel job) is sufficient for this project's traffic. No Azure resource cost from this phase itself.

## Next

Phase 11 — Monitoring.
