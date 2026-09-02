# Phase 2 — Networking

Goal: a VNet with subnets sized and segmented the way a real AKS deployment needs them, baseline NSGs (not wide-open), a route table, and a NAT Gateway for outbound egress. Builds on the resource group from [Phase 1](phase-01-identity.md).

> **Where this runs**: still your local machine — same as Phase 1. Immediately after this phase, [Phase 2b](phase-02b-management-vm.md) provisions a `snet-mgmt` subnet (planned into the CIDR table below) and a VM inside it; every phase after 2b runs from that VM instead.

## CIDR plan

VNet: `10.0.0.0/16` (65,536 addresses — generous headroom for later phases).

| Subnet | CIDR | Usable IPs | Why this size |
|---|---|---|---|
| `snet-aks` | `10.0.0.0/20` | 4,091 | AKS with Azure CNI assigns an IP per **pod**, not just per node — needs the largest range by far |
| `snet-appgw` | `10.0.16.0/24` | 251 | Application Gateway requires a dedicated subnet with no other resource types in it |
| `snet-data` | `10.0.17.0/24` | 251 | Reserved for private endpoints (SQL, Redis, Key Vault) added in Phases 6/9 — private endpoints consume one IP each, so 251 is ample |
| `snet-mgmt` | `10.0.18.0/24` | 251 | Isolated subnet for the Phase 2b management VM — kept separate from the workload subnets so its NSG can be locked down independently (see [Phase 2b](phase-02b-management-vm.md)) |

**Private vs public IP**: everything above is a private IP inside the VNet, unreachable from the internet directly. The only public IP in this phase is the one attached to the NAT Gateway (for AKS's *outbound* internet access — pulling images, calling Azure APIs). Inbound public exposure doesn't exist until Application Gateway is deployed in a later phase.

**Service endpoints vs private endpoints**: a *service endpoint* keeps traffic to a PaaS service (e.g. Storage) on the Azure backbone but the service still has a public-facing IP reachable only from allow-listed subnets. A *private endpoint* goes further — it gives the PaaS service an actual private IP inside your VNet (in `snet-data`), so it's not exposed publicly at all. This project uses private endpoints for SQL/Redis/Key Vault from Phase 6/9 onward, which is why `snet-data` exists now.

## What gets created

- 1 VNet, 4 subnets (above — `snet-mgmt` is created here in Terraform even though the VM itself lands in Phase 2b, since subnets and NSGs are the network module's job)
- 4 NSGs (one per subnet) with baseline rules — not a default-allow-all setup:
  - `snet-aks`: allow inbound from `snet-appgw`, `AzureLoadBalancer`, and `snet-mgmt` (so the admin VM can reach the AKS API/nodes), explicit deny from `Internet`
  - `snet-appgw`: allow inbound `80`/`443` from `Internet`, allow `65200-65535` from `GatewayManager` (App Gateway v2's own control-plane requirement)
  - `snet-data`: allow inbound only from `snet-aks` and `snet-mgmt`, explicit deny from `Internet`
  - `snet-mgmt`: allow inbound `22` (SSH) only from `var.admin_source_cidr` — your own IP, never `0.0.0.0/0` — explicit deny from `Internet` otherwise
- 1 Route Table, associated to `snet-aks`
- 1 Public IP (Standard SKU) + 1 NAT Gateway, associated to `snet-aks` for outbound egress

For what each of these actually is and why, see [`docs/azure-services/virtual-network-and-subnets.md`](../azure-services/virtual-network-and-subnets.md), [`network-security-groups.md`](../azure-services/network-security-groups.md), [`route-tables.md`](../azure-services/route-tables.md), and [`nat-gateway-and-public-ip.md`](../azure-services/nat-gateway-and-public-ip.md).

---

## Track A — Terraform

Continuing from Phase 1 (same `terraform/environments/prod` working directory, already initialized). `main.tf` also wires in `module.management_vm` (Phase 2b), so keep using `-target` for now to apply networking on its own before the VM exists — Phase 2b removes the target and does the full apply:

Set `admin_source_cidr` in your `terraform.tfvars` first (your IP from `curl -s ifconfig.me`, as `/32`) — the network module's `snet-mgmt` NSG requires it even though the VM itself isn't created until Phase 2b.

```bash
terraform -chdir=terraform/environments/prod plan -target=module.identity -target=module.network
terraform -chdir=terraform/environments/prod apply -target=module.identity -target=module.network
```

Terraform resolves the dependency (network module depends on `module.identity.resource_group_name`) automatically.

Check the new outputs:

```bash
terraform -chdir=terraform/environments/prod output aks_subnet_id
terraform -chdir=terraform/environments/prod output nat_gateway_public_ip
```

---

## Track B — Azure Portal (manual, same end result)

All inside `rg-ecommerce-prod` from Phase 1.

1. **VNet**: **+ Create a resource** → **Virtual network** → name `vnet-ecommerce-prod`, address space `10.0.0.0/16`, region matching Phase 1 → **Review + create**. Don't add subnets in this wizard — add them individually next so each gets its own NSG.

2. **Subnets**: open the new VNet → **Subnets** → **+ Subnet**, repeated four times:
   - `snet-aks`, address range `10.0.0.0/20`
   - `snet-appgw`, address range `10.0.16.0/24`
   - `snet-data`, address range `10.0.17.0/24`
   - `snet-mgmt`, address range `10.0.18.0/24`

3. **NSGs**: **+ Create a resource** → **Network security group**, create `nsg-ecommerce-aks-prod`, `nsg-ecommerce-appgw-prod`, `nsg-ecommerce-data-prod`, `nsg-ecommerce-mgmt-prod` (same region/RG). For each, open **Inbound security rules** → **+ Add** and enter the rules from the table above (source/destination, port ranges, priority, action) — for `nsg-ecommerce-mgmt-prod`, the one rule you need now is **Allow TCP/22 from your IP** (source: **IP Addresses**, your `/32`). Then, on each subnet's **Overview**, use **Associate ▸ Network security group** to attach the matching NSG.

4. **Route table**: **+ Create a resource** → **Route table** → name `rt-ecommerce-aks-prod` → create, then on `snet-aks` → **Route table** → associate it.

5. **Public IP + NAT Gateway**:
   - **+ Create a resource** → **Public IP address** → Standard SKU, name `pip-ecommerce-nat-prod`.
   - **+ Create a resource** → **NAT gateway** → name `nat-ecommerce-prod`, attach the public IP above, region matching the VNet.
   - On the NAT Gateway's **Subnets** blade, associate `snet-aks`.

---

## Verification

```bash
az network vnet show --name vnet-ecommerce-prod --resource-group rg-ecommerce-prod --output table
az network vnet subnet list --vnet-name vnet-ecommerce-prod --resource-group rg-ecommerce-prod --output table
az network nsg list --resource-group rg-ecommerce-prod --output table
az network nat gateway show --name nat-ecommerce-prod --resource-group rg-ecommerce-prod --output table
```

Confirm 4 subnets, 4 NSGs each showing the rules above, and the NAT gateway attached to `snet-aks` with the public IP allocated.

## Teardown

Most networking resources here are free (VNet, subnets, NSGs, route table). The NAT Gateway and its Standard public IP are the exceptions — see [`docs/cost-management.md`](../cost-management.md) for the exact `terraform destroy -target=...` command to remove just those two (safe to do, nothing else depends on them until Phase 5's AKS nodes exist) and the plain `terraform apply` that recreates them from code next session.

## Next: Phase 2b

With `snet-mgmt` and its NSG in place, move on to [`docs/deployment_phases/phase-02b-management-vm.md`](phase-02b-management-vm.md) to provision the admin VM inside it.
