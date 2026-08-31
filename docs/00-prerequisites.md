# 00 — Prerequisites

One-time setup before Phase 1. Do this locally in your own terminal — nothing here is run on your behalf.

## 0. How this project is set up: two machines, not one

This project uses a **management VM in Azure** (built in Phase 2b, right after Networking) as the admin/jump box for everything past that point — every `terraform apply`, every `kubectl`, every `docker build`, every `az` command from Phase 3 onward runs **from that VM**, not from your laptop. That's a deliberately production-style pattern: infrastructure operations happen from a controlled, auditable box inside the VNet, not from whatever machine happens to be on someone's desk.

That creates one chicken-and-egg problem: the VM can't create itself. So your **local machine's job is narrow and temporary** — install a minimal toolset, then use it only to stand up Phase 1 (Identity), Phase 2 (Networking), and Phase 2b (the VM itself). After that, you SSH into the VM and do everything else from there; the VM comes pre-loaded (via cloud-init) with Terraform, Azure CLI, Docker, kubectl, Helm, and Node.js — see `docs/phases/phase-02b-management-vm.md` for the full list and how it's provisioned.

| | Installs | Used for |
|---|---|---|
| **Local machine** (this doc) | Azure CLI, Terraform, Git, an SSH client | Bootstrapping the Terraform state backend, applying Phases 1/2/2b, then SSHing to the VM |
| **Management VM** (`docs/phases/phase-02b-management-vm.md`) | Azure CLI, Terraform, Docker, kubectl, Helm, Node.js — all via cloud-init at boot | Every phase from 3 onward: AKS, databases, messaging, CI/CD, monitoring, security |

## 1. Install local bootstrap tooling

| Tool | Why | Install (Windows) | Verify |
|---|---|---|---|
| Azure CLI | Authenticate, run the Phase 1/2/2b Terraform | `winget install Microsoft.AzureCLI` | `az version` |
| Terraform | Apply Phase 1/2/2b infrastructure | `winget install HashiCorp.Terraform` | `terraform version` |
| Git | Version control | `winget install Git.Git` | `git --version` |
| SSH client | Connect to the management VM once it exists | Built into Windows 10/11 (`ssh`), or use Git Bash's | `ssh -V` |

Restart your terminal after installing so `PATH` updates take effect.

Node.js is optional locally — install it (`winget install OpenJS.NodeJS.LTS`) only if you want to run the demo services (`services/*`) directly on your laptop before pushing; it's unnecessary for the infrastructure work below.

## 2. Generate an SSH key pair (for the management VM)

The management VM (Phase 2b) is key-only — no password login. If you don't already have a key pair:

```bash
ssh-keygen -t ed25519 -C "your-email@example.com" -f "$HOME/.ssh/ecommerce_mgmt_vm"
```

This creates `~/.ssh/ecommerce_mgmt_vm` (private, never share it) and `~/.ssh/ecommerce_mgmt_vm.pub` (public — this is what goes into Terraform/the Portal). Print the public key when you need to paste it:

```bash
cat ~/.ssh/ecommerce_mgmt_vm.pub
```

## 3. Azure subscription

You need an active Azure subscription (free trial, pay-as-you-go, or Visa/student credit all work — this project targets the ~$200 credit tier).

- Portal: [portal.azure.com](https://portal.azure.com) → confirm you can see **Subscriptions** and at least one subscription is listed.
- If you don't have one yet, create it at [azure.microsoft.com/free](https://azure.microsoft.com/free) via the Portal signup flow.

## 4. Log in from the CLI

```bash
az login
az account list --output table
az account set --subscription "<your-subscription-name-or-id>"
az account show --output table
```

###### xxx Output xxx ######
PS C:\Users\Zaryab> az login --tenant 3ab5e04f-6860-4285-9f21-d0a670f3baa5
Select the account you want to log in with. For more information on login with Azure CLI, see https://go.microsoft.com/fwlink/?linkid=2271136

Retrieving subscriptions for the selection...

[Tenant and subscription selection]

No     Subscription name    Subscription ID                       Tenant
-----  -------------------  ------------------------------------  ------------------------------------
[1] *  PROD                 93f65dd4-0dba-417d-a471-d32e5de97e54  3ab5e04f-6860-4285-9f21-d0a670f3baa5

The default is marked with an *; the default tenant is '3ab5e04f-6860-4285-9f21-d0a670f3baa5' and subscription is 'PROD' (93f65dd4-0dba-417d-a471-d32e5de97e54).

Select a subscription and tenant (Type a number or Enter for no changes):

Tenant: 3ab5e04f-6860-4285-9f21-d0a670f3baa5
Subscription: PROD (93f65dd4-0dba-417d-a471-d32e5de97e54)

[Announcements]
With the new Azure CLI login experience, you can select the subscription you want to use more easily. Learn more about it and its configuration at https://go.microsoft.com/fwlink/?linkid=2271236

If you encounter any problem, please open an issue at https://aka.ms/azclibug

[Warning] The login output has been updated. Please be aware that it no longer displays the full list of available subscriptions by default.

PS C:\Users\Zaryab> az account show
{
  "environmentName": "AzureCloud",
  "homeTenantId": "3ab5e04f-6860-4285-9f21-d0a670f3baa5",
  "id": "93f65dd4-0dba-417d-a471-d32e5de97e54",
  "isDefault": true,
  "managedByTenants": [],
  "name": "PROD",
  "state": "Enabled",
  "tenantId": "3ab5e04f-6860-4285-9f21-d0a670f3baa5",
  "user": {
    "name": "zaryabansarinccpl2059@gmail.com",
    "type": "user"
  }
}
PS C:\Users\Zaryab> az account list --output table
Name    CloudName    SubscriptionId                        TenantId                              State    IsDefault
------  -----------  ------------------------------------  ------------------------------------  -------  -----------
PROD    AzureCloud   93f65dd4-0dba-417d-a471-d32e5de97e54  3ab5e04f-6860-4285-9f21-d0a670f3baa5  Enabled  True
PS C:\Users\Zaryab>
###### xxx Output xxx ######



Keep a note of your **Subscription ID** and **Tenant ID** (from `az account show`) — Terraform's provider block needs them (see `docs/phases/phase-01-identity.md`).

Also find your current public IP now — you'll need it as `admin_source_cidr` for the management VM's NSG (Phase 2b), so SSH is locked to just you:

```bash
curl -s ifconfig.me
```

## 5. The Terraform remote-state bootstrap problem

Terraform's `azurerm` backend (used in `terraform/environments/prod/backend.tf`) stores state as a blob in an Azure Storage Account. That storage account itself can't be created *by* the same Terraform run that needs it — it has to exist first. This one piece is the only infrastructure in this project created outside of Terraform.

**Option A — script** (`scripts/bootstrap-terraform-backend.ps1`, PowerShell, idempotent):

```powershell
./scripts/bootstrap-terraform-backend.ps1 -Location "eastus"
```

It creates:
- Resource group `rg-tfstate` (separate from the app's resource group, so it survives even if you tear down the app RG between sessions)
- Storage account `stecommercetfstate<random-suffix>` (Standard_LRS, TLS1.2 minimum)
- Blob container `tfstate`

It prints the storage account name at the end — copy it into `terraform/environments/prod/backend.tf` (or pass via `-backend-config` at `terraform init`, see `docs/phases/phase-01-identity.md`).

**Option B — Azure Portal**, if you'd rather see it happen by hand:

1. Portal → **Resource groups** → **Create** → name `rg-tfstate`, region e.g. East US → **Review + create**.
2. Inside that RG → **Create** → **Storage account** → globally-unique name (e.g. `stecommercetfstate1234`) → Standard performance, LRS redundancy → **Review + create**.
3. Open the new storage account → **Data storage → Containers** → **+ Container** → name `tfstate`, access level **Private**.

Either way, the result is the same three things Terraform needs: RG, storage account, container.

## 6. Cost discipline reminder

This project's biggest costs are AKS (Phase 5+) and the always-on management VM (Phase 2b). Stop resources between sessions rather than leaving them running 24/7 — **the VM specifically should always be stopped, never deleted** (deallocating already removes all its compute cost; deleting it buys nothing extra and loses your SSH host keys/in-progress state):

```bash
./scripts/stop-management-vm.ps1    # or: az vm deallocate --name vm-ecommerce-mgmt-prod --resource-group rg-ecommerce-prod
./scripts/start-management-vm.ps1   # or: az vm start --name vm-ecommerce-mgmt-prod --resource-group rg-ecommerce-prod
```

See [`docs/cost-management.md`](cost-management.md) for the full breakdown of every billed resource in the project, which ones can be stopped vs. must be deleted/recreated, and the exact commands — kept up to date as later phases add AKS, SQL, Redis, etc.
