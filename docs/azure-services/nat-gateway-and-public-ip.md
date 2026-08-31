# NAT Gateway & Public IP

## What they are

A **Public IP** is an internet-routable address you can attach to a resource (a VM's NIC, a NAT Gateway, a Load Balancer, ...). A **NAT Gateway** is a managed outbound-only gateway: attach it to a subnet, give it a public IP, and every resource in that subnet can now reach the internet *outbound* through it — without any of those individual resources needing their own public IP, and without any way for the internet to *initiate* a connection back in. Outbound-only is the key property.

## Why this project uses it

AKS nodes (from Phase 5) will need outbound internet access — pulling container images, calling Azure APIs, reaching package registries — but should never be individually internet-addressable. The alternative (giving every node its own public IP) is both a bigger attack surface and doesn't scale cleanly as the node count changes. A NAT Gateway solves this once, at the subnet level: one shared public IP, outbound-only, for the whole `snet-aks` subnet.

## Where it's wired in

`terraform/modules/network/main.tf`:
- `azurerm_public_ip.nat` — Standard SKU, Static allocation (a Basic SKU or Dynamic allocation wouldn't work correctly with a NAT Gateway)
- `azurerm_nat_gateway.main` — the gateway itself
- `azurerm_nat_gateway_public_ip_association.main` — attaches the IP
- `azurerm_subnet_nat_gateway_association.aks` — attaches the gateway to `snet-aks`

## The other public IP in this project

The management VM (Phase 2b) also has its own Standard, Static public IP — but for the opposite reason: it needs **inbound** SSH access, which a NAT Gateway (outbound-only) can't provide. That IP is locked down by its own NSG to your admin IP only (see [network-security-groups.md](network-security-groups.md)), which is the actual security control — the public IP itself is just an address, not a permission.

## Cost note

Unlike almost everything else in Phases 1–2, the NAT Gateway and its public IP are **billed hourly regardless of use** — Azure doesn't offer a "stop" for them. See [`docs/cost-management.md`](../cost-management.md) for the exact `terraform destroy -target=...` command to remove them during an extended pause, and the plain `terraform apply` that recreates them from code.
