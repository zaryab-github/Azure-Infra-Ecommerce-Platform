# Phase 1 — Identity

Goal: a resource group, a way for Terraform/CI to authenticate, and a managed identity AKS workloads will use later — without any credentials stored in code.

Prerequisite: complete [`docs/00-prerequisites.md`](../00-prerequisites.md) first (tools installed, `az login` done, Terraform backend bootstrapped).

> **Where this runs**: this phase and Phase 2 are the only phases run from your local machine. Right after Phase 2, [Phase 2b](phase-02b-management-vm.md) stands up a management VM, and every phase after that runs from there instead. See `docs/00-prerequisites.md` §0.

## What gets created

| Resource | Purpose |
|---|---|
| Resource Group `rg-ecommerce-prod` | Container for every resource in this project |
| Entra ID App Registration + Service Principal `sp-ecommerce-terraform-prod` | Identity Terraform/CI authenticates as, scoped to Contributor on the resource group only |
| User-Assigned Managed Identity `id-ecommerce-aks-prod` | Identity AKS workloads use from Phase 5 on, so pods never hold a stored secret |
| Role assignment | Contributor, scoped to the resource group (not the subscription) |

For what each of these actually is, why it exists, and how it's used elsewhere in the project, see [`docs/azure-services/resource-groups.md`](../azure-services/resource-groups.md), [`entra-id-and-service-principals.md`](../azure-services/entra-id-and-service-principals.md), [`azure-rbac.md`](../azure-services/azure-rbac.md), and [`managed-identity.md`](../azure-services/managed-identity.md).

---

## Track A — Terraform

1. Copy the example vars file and fill in your subscription/tenant IDs:

   ```bash
   cp terraform/environments/prod/terraform.tfvars.example terraform/environments/prod/terraform.tfvars
   ```

   Edit `subscription_id` / `tenant_id` using the values from `az account show`.

2. Initialize, pointing at the state backend created by the bootstrap script (values printed at the end of that script's output):

   ```bash
   terraform -chdir=terraform/environments/prod init \
     -backend-config="resource_group_name=rg-tfstate" \
     -backend-config="storage_account_name=<your-storage-account-name>" \
     -backend-config="container_name=tfstate" \
     -backend-config="key=prod.terraform.tfstate"
   ```

3. Review and apply just the identity module first, so you can inspect what it creates before networking is added on top:

   ```bash
   terraform -chdir=terraform/environments/prod plan -target=module.identity
   terraform -chdir=terraform/environments/prod apply -target=module.identity
   ```

4. Inspect the outputs:

   ```bash
   terraform -chdir=terraform/environments/prod output
   ```

   `terraform_sp_password` is marked sensitive — reveal it only if you need it: `terraform -chdir=terraform/environments/prod output -raw terraform_sp_password`.

**Note on the Terraform service principal secret**: `azuread_service_principal_password` creates a client secret with a 1-year expiry (`main.tf` in the identity module). That's fine for a portfolio lab. In a real production setup you'd use OIDC workload identity federation for Azure DevOps/GitHub Actions instead, avoiding a stored secret entirely — set `create_terraform_service_principal = false` in your tfvars and wire that up separately if you want to practice it later.





---

## Track B — Azure Portal (manual, same end result)

Use this to see each piece created by hand, or to sanity-check what Terraform did.

1. **Resource group**: Portal → **Resource groups** → **+ Create** → name `rg-ecommerce-prod`, region matching your Terraform `location` var → **Review + create**.

2. **App registration** (Terraform/CI identity):
   - Portal → **Microsoft Entra ID** → **App registrations** → **+ New registration** → name `sp-ecommerce-terraform-prod`, single tenant → **Register**.
   - On the app's **Overview**, note the **Application (client) ID** and **Directory (tenant) ID**.
   - **Certificates & secrets** → **+ New client secret** → set an expiry, copy the secret value immediately (shown once).

3. **Role assignment** (scope the app to the resource group, not the subscription):
   - Open `rg-ecommerce-prod` → **Access control (IAM)** → **+ Add** → **Add role assignment**.
   - Role: **Contributor**. Members: select the `sp-ecommerce-terraform-prod` app registration. → **Review + assign**.

4. **Managed identity** (for AKS, used starting Phase 5):
   - Inside `rg-ecommerce-prod` → **+ Create a resource** → search **User Assigned Managed Identity** → name `id-ecommerce-aks-prod`, same region → **Review + create**.

- A User-Assigned Managed Identity lets AKS pods securely authenticate to Azure services (like Key Vault) without storing credentials or secrets inside the application.
      ---
      Create:
      id-ecommerce-aks-prod

            │

      Phase 5
      --------

      AKS Cluster
            │
      Uses Workload Identity
            │
            ▼
      Pod
            │
            ▼
      Uses id-ecommerce-aks-prod
            │
            ▼
      Azure issues an access token
            │
            ▼
      Azure Key Vault
            │
            ▼
      Returns the secret

---



---

#### Working of Service principle (little bit same as GCP service account)

1. Create App Registration
        │
        ▼
2. Create Service Principal
        │
        ▼
3. Assign RBAC Role(s)
        │
        ▼
4. Create Client Secret (or use OIDC/certificate)
        │
        ▼
5. Terraform authenticates using:
   - Client ID
   - Client Secret
   - Tenant ID
   - Subscription ID

GCP Service Account ≈ Azure Service Principal


## Verification

```bash
az group show --name rg-ecommerce-prod --output table
az ad sp list --display-name "sp-ecommerce-terraform-prod" --output table
az identity show --name id-ecommerce-aks-prod --resource-group rg-ecommerce-prod --output table
az role assignment list --resource-group rg-ecommerce-prod --output table
```

All four commands should return the resources you just created (via either track).

## Teardown (between sessions, to save cost)

Identity resources are free — leave them in place as the foundation for Phase 2 onward. See [`docs/cost-management.md`](../cost-management.md) for the running list of what in this project actually costs money and how to stop/delete it.
