# Virtual Network & Subnets

## What it is

A Virtual Network (VNet) is an isolated private network inside Azure — your own address space, not shared with or reachable from anyone else's Azure resources by default. A **subnet** divides that address space into smaller ranges, each of which can carry its own routing, security rules (NSG), and resource-type restrictions (some Azure services, like Application Gateway, require a subnet dedicated to just them).

## Why this project uses it

Every resource that needs to talk privately to another resource in this project — AKS nodes talking to a database, the management VM talking to AKS — needs to live on a shared private network. Splitting that network into subnets by *role* (not just "one big flat network") is what lets each role get its own security posture:

| Subnet | CIDR | Role |
|---|---|---|
| `snet-aks` | `10.0.0.0/20` | AKS nodes and pods (Azure CNI assigns pod IPs from here — hence the large range) |
| `snet-appgw` | `10.0.16.0/24` | Application Gateway (Azure requires this to be its own dedicated subnet) |
| `snet-data` | `10.0.17.0/24` | Private endpoints for SQL/Redis/Key Vault (Phases 6/9) |
| `snet-mgmt` | `10.0.18.0/24` | The management VM, isolated from every workload subnet |

Full CIDR sizing rationale: [`docs/deployment_phases/phase-02-networking.md`](../deployment_phases/phase-02-networking.md).

## Where it's wired in

`terraform/modules/network/main.tf` — `azurerm_virtual_network.main` and four `azurerm_subnet` resources (`aks`, `appgw`, `data`, `mgmt`).

## Private vs. public IP, and why it matters here

Every address in this VNet (`10.0.0.0/16`) is a private IP, unreachable from the public internet directly — that's the whole point of a VNet. The only public-facing IPs in this project are attached explicitly and deliberately: the NAT Gateway's IP (outbound-only egress, see [nat-gateway-and-public-ip.md](nat-gateway-and-public-ip.md)) and the management VM's IP (inbound SSH, locked to one source IP by its NSG). Nothing else is reachable from outside the VNet until Application Gateway is deployed (Phase 5+) as the one deliberate, WAF-protected entry point.
