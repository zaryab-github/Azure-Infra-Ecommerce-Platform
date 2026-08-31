# Phase 2b — Management VM

*A custom addition to the original roadmap PDF, inserted between Phase 2 (Networking) and Phase 3 (Infrastructure as Code).*

Goal: a dedicated admin/jump VM inside the VNet — in its own isolated subnet, not the AKS/data subnets — that becomes the single place every later phase runs its Terraform/kubectl/docker/az commands from. This is the last phase you run from your local machine; everything after this you do from inside this VM over SSH.

## Why a management VM, and why its own subnet

Running infrastructure tooling from a laptop is fine for a first pass, but it doesn't reflect how a real team operates: credentials, `kubectl` contexts, and Terraform state access are typically confined to a small number of controlled bastion/jump machines, not scattered across every engineer's laptop. This phase reproduces that pattern at small scale:

- **Separate subnet (`snet-mgmt`, `10.0.18.0/24`)**, not just a separate NSG on an existing subnet — so its network boundary is structural, not just a rule that could be edited to leak. It sits in the *same VNet* as `snet-aks`/`snet-appgw`/`snet-data` (so it can reach them directly over private IPs) but is never on the path of production traffic.
- **NSG locked to one source IP** (`var.admin_source_cidr`) on port 22 only — not `0.0.0.0/0`. If your IP changes, you update one Terraform variable and re-apply.
- **No stored secrets on the box.** The VM gets a system-assigned managed identity with Contributor scoped to the resource group. On the VM, `az login --identity` authenticates as that identity — no service-principal password or `.tfvars` secret needs to live on disk there.
- **Key-only SSH**, password authentication disabled at the VM level.

## What gets created

| Resource | Purpose |
|---|---|
| `azurerm_public_ip` (Standard, Static) | So you can SSH to the VM from outside Azure |
| `azurerm_network_interface` | In `snet-mgmt`, bound to the public IP |
| `azurerm_linux_virtual_machine` (`Standard_B2s`, Ubuntu 22.04 LTS) | The VM itself — sized small/cheap; resize later if builds feel slow |
| System-assigned managed identity + `Contributor` role assignment (RG-scoped) | Lets the VM run Terraform/az without a stored secret |
| Cloud-init bootstrap (`terraform/modules/management-vm/cloud-init.yaml`) | Installs Azure CLI, Terraform, Docker, kubectl, Helm, Node.js 20 automatically on first boot |

See [`docs/azure-services/virtual-machines.md`](../azure-services/virtual-machines.md) and [`managed-identity.md`](../azure-services/managed-identity.md) for what these actually are and why.

## Track A — Terraform

Still from your local machine (last time for infrastructure work):

1. Make sure `terraform.tfvars` has `admin_source_cidr` set (from Phase 2) and add:

   ```hcl
   mgmt_ssh_public_key = "ssh-ed25519 AAAA... your-email@example.com"
   ```

   Paste the contents of the public key you generated in `docs/00-prerequisites.md` §2 (`cat ~/.ssh/ecommerce_mgmt_vm.pub`).

2. Apply everything — now that the VM's inputs are ready, drop `-target` and let Terraform reconcile all three modules (`identity`, `network`, `management_vm`) in one pass:

   ```bash
   terraform -chdir=terraform/environments/prod plan
   terraform -chdir=terraform/environments/prod apply
   ```

3. Get the VM's public IP:

   ```bash
   terraform -chdir=terraform/environments/prod output mgmt_vm_public_ip
   ```

4. SSH in (cloud-init runs on first boot — give it 2-3 minutes before everything is installed):

   ```bash
   ssh -i ~/.ssh/ecommerce_mgmt_vm azureadmin@<mgmt_vm_public_ip>
   ```

5. On the VM, confirm the bootstrap finished and everything installed:

   ```bash
   cat /var/log/mgmt-vm-bootstrap-done.log
   az version && terraform version && docker --version && kubectl version --client && helm version && node -v
   ```

6. Log in as the VM's own managed identity (no secrets involved) and confirm it can see the resource group:

   ```bash
   az login --identity
   az group show --name rg-ecommerce-prod --output table
   ```

7. From here on, clone this repo onto the VM (or `scp`/`rsync` it over) and run every subsequent phase's Terraform/kubectl from inside this SSH session.

## Track B — Azure Portal (manual, same end result)

1. **Public IP**: **+ Create a resource** → **Public IP address** → Standard SKU, name `pip-ecommerce-mgmt-prod`.
2. **Virtual machine**: **+ Create a resource** → **Virtual machine**:
   - Resource group `rg-ecommerce-prod`, name `vm-ecommerce-mgmt-prod`, region matching the rest.
   - Image: **Ubuntu Server 22.04 LTS - x64 Gen2**. Size: **Standard_B2s**.
   - Authentication type: **SSH public key**. Paste the contents of your `.pub` file. Username: `azureadmin`.
   - **Networking** tab: select the existing VNet, subnet `snet-mgmt`, and attach the `pip-ecommerce-mgmt-prod` public IP created above. Select the existing `nsg-ecommerce-mgmt-prod` NSG (don't let the wizard create a new permissive one).
   - **Advanced** tab → **Custom data**: paste the contents of `terraform/modules/management-vm/cloud-init.yaml`, with `${admin_username}` manually replaced by `azureadmin` (the Portal doesn't do template substitution).
   - **Management** tab → **Identity**: turn on **System assigned managed identity**.
   - Review + create.
3. **Role assignment**: once created, open the VM → **Identity** → copy the **Object (principal) ID**. Then go to `rg-ecommerce-prod` → **Access control (IAM)** → **Add role assignment** → role **Contributor** → assign to that managed identity (search by the VM's name under "Managed identity", not "User").
4. SSH in the same way as the Terraform track, and verify the same way.

## Verification

```bash
az vm show --name vm-ecommerce-mgmt-prod --resource-group rg-ecommerce-prod --output table
az vm identity show --name vm-ecommerce-mgmt-prod --resource-group rg-ecommerce-prod
az role assignment list --resource-group rg-ecommerce-prod --output table
```

The identity's principal ID should appear in the role assignment list with role `Contributor`.

## Teardown / cost control

**Stop this VM every session — never delete it.** Deallocating removes 100% of its compute billing; deleting and recreating it buys nothing extra in cost savings but does cost you SSH host keys and any in-progress state on the box. See [`docs/cost-management.md`](../cost-management.md) for the full policy and why it applies specifically to this resource.

```bash
./scripts/stop-management-vm.ps1
./scripts/start-management-vm.ps1
```

or directly:

```bash
az vm deallocate --name vm-ecommerce-mgmt-prod --resource-group rg-ecommerce-prod   # stop billing
az vm start --name vm-ecommerce-mgmt-prod --resource-group rg-ecommerce-prod       # resume next session
```

The public IP doesn't change across deallocate/start — it's a Static Standard IP, retained and re-associated automatically.

## Next

Continue to Phase 3 (Infrastructure as Code) and onward **from inside this VM**, per `docs/ROADMAP.md`.
