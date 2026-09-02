# Network Security Groups (NSG)

## What it is

An NSG is a stateful firewall: an ordered list of allow/deny rules (by source, destination, port, protocol, priority) evaluated against traffic entering or leaving a subnet or network interface. Azure evaluates rules in priority order (lowest number first) and stops at the first match — so ordering and priority numbers matter.

## Why this project uses it

Every subnet in this project has its own NSG, and every one of them ends with an **explicit deny from `Internet`** — nothing here relies on "there's no rule allowing it in, so it's fine." That's a deliberate production-style posture: default-deny, then allow exactly what's needed, rather than default-allow with holes patched over time.

| Subnet | NSG allows inbound from | Denies |
|---|---|---|
| `snet-aks` | `snet-appgw`, `AzureLoadBalancer`, `snet-mgmt` | `Internet` (explicit) |
| `snet-appgw` | `Internet` on 80/443, `GatewayManager` on 65200-65535 (App Gateway v2's own control-plane requirement) | everything else, implicitly |
| `snet-data` | `snet-aks`, `snet-mgmt` | `Internet` (explicit) |
| `snet-mgmt` | `var.admin_source_cidr` (your IP) on port 22 only | `Internet` (explicit) — never `0.0.0.0/0` |

## Where it's wired in

`terraform/modules/network/main.tf` — four `azurerm_network_security_group` resources plus their `azurerm_subnet_network_security_group_association` bindings. See [`docs/deployment_phases/phase-02-networking.md`](../deployment_phases/phase-02-networking.md) for the full rule tables and Portal equivalent.

## Why `snet-mgmt`'s rule matters most

The management VM's NSG is the single most security-sensitive rule in this project — it's the one thing standing between "only I can SSH in" and "anyone on the internet can try." `var.admin_source_cidr` has **no default value** in Terraform specifically so it can't be silently left at `0.0.0.0/0` — you must set it deliberately (see `docs/00-prerequisites.md` for finding your IP). If your IP changes (new location, ISP reassigns it), update this one variable and re-apply — don't widen the rule as a workaround.

## Service endpoints and private endpoints (a related, but different, concept)

NSGs control network-level access; they're not the mechanism used for reaching Azure PaaS services (Storage, SQL, Key Vault) privately — that's what `snet-data` and private endpoints are for, covered in each relevant service's own doc once those phases land (Phase 6, 8, 9).
