# Virtual Machines

## What it is

An Azure Virtual Machine is standard IaaS compute — you pick an image, a size, and get a full OS you manage yourself (patching, packages, everything), unlike PaaS services where Azure manages the runtime for you.

## Why this project uses one

This is the one place in the project's core roadmap where a VM isn't strictly required by the architecture diagram — it's a deliberate addition (Phase 2b) for a specific reason: giving infrastructure operations (Terraform, kubectl, docker, az) a controlled, auditable home inside the VNet, rather than running them from whatever laptop happens to be nearby. See [`docs/deployment_phases/phase-02b-management-vm.md`](../deployment_phases/phase-02b-management-vm.md) for the full rationale and setup steps.

## Where it's wired in

`terraform/modules/management-vm/main.tf` — `azurerm_linux_virtual_machine.mgmt`:
- **Image**: Ubuntu Server 22.04 LTS, Gen2
- **Size**: `Standard_B2s` — a burstable, low-cost size; enough for `terraform apply`, `docker build`, and `kubectl`, resize later if builds feel slow
- **Auth**: SSH public key only, `disable_password_authentication = true`
- **Identity**: system-assigned managed identity (see [managed-identity.md](managed-identity.md)) instead of a stored credential
- **Bootstrap**: `custom_data` (cloud-init) installs Azure CLI, Terraform, Docker, kubectl, Helm, and Node.js automatically on first boot — see `terraform/modules/management-vm/cloud-init.yaml`

## Networking

Lives in `snet-mgmt`, its own isolated subnet (see [virtual-network-and-subnets.md](virtual-network-and-subnets.md)), with an NSG (see [network-security-groups.md](network-security-groups.md)) that only allows inbound SSH from one admin IP. It has its own Standard, Static public IP for that inbound access.

## Cost — the one resource with a firm policy

**Stop it, never delete it.** `az vm deallocate` removes 100% of its compute billing; the VM, its disk, and its (Static) public IP remain — nothing is lost, and starting it back up is fast. Deleting and recreating it buys no extra savings over deallocating, but does lose SSH host keys and any in-progress work on the box. See [`docs/cost-management.md`](../cost-management.md) and `scripts/stop-management-vm.ps1` / `scripts/start-management-vm.ps1`.

## Future VM use in this project

None currently planned — AKS (Phase 5) runs its own managed node VMs, but those are provisioned and managed by AKS itself, not as standalone `azurerm_linux_virtual_machine` resources like this one.
