# Cost management — stop, delete, and recreate

Everything in this project is Terraform-managed, which gives two different ways to stop paying for something:

1. **Stop/deallocate it** — the resource still exists (and still shows up in `terraform plan` as unchanged), it's just powered off and not billed for compute. Fast to resume. This is the *only* option for the management VM (per project policy — see below) and works for AKS node pools once Phase 5 lands.
2. **Delete it, recreate it from code next time** — for resources Azure doesn't let you "stop" (NAT Gateway, Public IPs, and later Azure SQL/Redis), the only way to stop paying is to delete them, via `terraform destroy -target=...`. Since everything is code, `terraform apply` recreates the exact same resource next session. This only works cleanly for stateless infrastructure — don't do this for anything holding data you haven't backed up (a real production SQL database, for instance) without a separate backup/export step first, which later phases will call out explicitly if it applies.

This file is the index of what's billed, which of the two options applies, and the exact command. Each phase's own doc also has a short "Teardown" section — this page is the consolidated version to check before ending a session.

## The rule for the management VM specifically

**Stop it, never delete it.** The VM is where your Terraform state workflow, SSH host keys, and any in-progress work live day to day — deleting and recreating it is disruptive for no cost benefit (deallocating already stops 100% of its compute billing; only the tiny disk/IP holding cost remains). Use:

```bash
./scripts/stop-management-vm.ps1
./scripts/start-management-vm.ps1
```

or directly:

```bash
az vm deallocate --name vm-ecommerce-mgmt-prod --resource-group rg-ecommerce-prod
az vm start --name vm-ecommerce-mgmt-prod --resource-group rg-ecommerce-prod
```

`deallocate` (not `stop`) is what actually stops compute billing — `az vm stop` alone leaves you paying. Its Static Standard public IP is retained and reattached automatically on start, so the SSH command / IP you've saved doesn't change.

## What's billed, full project (Phases 1–13)

| Resource | Can it be stopped? | Action to save cost | Approx. cost if left running |
|---|---|---|---|
| Management VM (`Standard_B2s`) | Yes — deallocate | `./scripts/stop-management-vm.ps1` | ~$30–35/mo if run 24/7; **$0 while deallocated** |
| AKS cluster (`Standard_B2s`, 1 node, Free SKU tier) | Yes — `az aks stop` | `az aks stop --name aks-ecommerce-prod --resource-group rg-ecommerce-prod` / `az aks start ...` | ~$25–40/mo if run 24/7; **$0 while stopped** (control plane is already free) |
| Azure SQL (Serverless, auto-pause 60 min) | Self-pauses | Nothing to do — it pauses on idle automatically | Near-$0 when idle; ~$5–15/mo under light active use |
| Application Gateway (WAF_v2, autoscale min 0) | No hard stop, but scales to near-zero capacity units when idle | Delete via `terraform destroy -target=module.appgateway` for an extended pause | ~$0.36/hr base + usage — the single most expensive *always-on* piece once Phase 12 is deployed |
| NAT Gateway | No | Delete via Terraform, recreate next session (below) | ~$32/mo (hourly) + data processing |
| Standard Public IPs (NAT + VM + App Gateway, 3 total) | No | Delete via Terraform along with their owning resource | ~$3.50/mo each |
| ACR (Basic) | No | Effectively free — leave running | ~$5/mo flat |
| Service Bus (Basic) | No | Effectively free — leave running | Low, usage-based |
| Storage Account | No | Effectively free at this scale — leave running | <$2/mo |
| Key Vault | No | Effectively free at this scale — leave running | Negligible |
| Log Analytics + Application Insights | No | Keep ingestion low (this project's traffic is tiny) | Usage-based, low here |
| Defender for Cloud | N/A | Kept at **Free** tier by default (`defender_tier` var) | $0 at Free tier |
| Resource Group, VNet/subnets, NSGs, Route Table, Entra ID app/SP, Managed Identity, Azure Policy assignments | N/A | Free — leave these running always | $0 |

Not built in this project: Azure Cache for Redis (listed as optional in the roadmap's architecture diagram — no `terraform/modules/redis` exists; add one following the same pattern as `sql`/`servicebus` if you want it).

Practical guidance: for a normal working session, just stop the VM (`az vm deallocate`) at the end and start it again next time — that alone removes the overwhelming majority of the daily cost. Only bother deleting the NAT Gateway/Public IPs if you're pausing the project for an extended stretch (a week+), since they're a much smaller cost and deleting/recreating them means also re-running Terraform for the network module.

### Deleting the NAT Gateway (extended pause only)

```bash
terraform -chdir=terraform/environments/prod destroy \
  -target=module.network.azurerm_subnet_nat_gateway_association.aks \
  -target=module.network.azurerm_nat_gateway_public_ip_association.main \
  -target=module.network.azurerm_nat_gateway.main \
  -target=module.network.azurerm_public_ip.nat
```

This is safe — nothing else in the network module depends on the NAT Gateway existing, since it only provides outbound internet egress for `snet-aks` (not used by anything until Phase 5's AKS nodes exist anyway). Recreate it later with a plain:

```bash
terraform -chdir=terraform/environments/prod apply
```

Terraform reconciles state and adds back only what's missing.

## Recommended daily routine

For a normal working session: `./scripts/start-management-vm.ps1` → `az aks start ...` at the start, work, then `az aks stop ...` → `./scripts/stop-management-vm.ps1` at the end. That covers the two resources with real, meaningful, stoppable cost. Everything else in the table above is either free, auto-pausing, or cheap enough to leave running continuously without meaningfully denting a $200 credit.

## General pattern for any future costly resource

1. Check whether Azure offers a genuine "stop" for it (VMs, AKS, some managed databases do; most networking/PaaS resources don't).
2. If yes — stop/deallocate/pause it via `az`, exactly like the VM above. Never delete something that has a real stop option.
3. If no — and it holds no data you'd lose — `terraform destroy -target=<the specific resource>` it, and `terraform apply` to bring it back. Keep targets narrow (name the exact resource(s), not the whole module) so you don't accidentally take down something a still-running resource depends on.
4. If no, and it *does* hold data (a database with real rows in it) — don't delete-and-recreate as a cost-saving move without an explicit backup/export step. The phase doc that introduces that resource will say so.
