# Roadmap — Azure Enterprise DevOps Platform

Condensed from `Azure_Ecommerce_Platform_Roadmap.pdf`. This file is the durable source of truth for "what's next" — no need to re-read the PDF in future sessions. Status is updated as each phase is completed.

| # | Phase | Status | What it builds |
|---|-------|--------|-----------------|
| 1 | Identity | ✅ Done | Resource Group, Entra ID app registration + service principal, managed identity, RBAC |
| 2 | Networking | ✅ Done | VNet, subnets (aks/appgw/data/mgmt), NSGs, route table, public IP, NAT gateway |
| 2b | Management VM *(custom addition, not in the original PDF)* | ✅ Done | A dedicated admin/jump VM in `snet-mgmt`, isolated from workload subnets. From here on, Terraform/kubectl/docker/az commands run from this VM, not your laptop |
| 3 | Infrastructure as Code | ✅ Done | Terraform module structure (`network`, `aks`, `sql`, `monitoring`, `keyvault`, `acr`) — no portal clicks after subscription setup |
| 4 | Azure Container Registry | ⬜ Not started | ACR (Basic), build/push the 3 service images |
| 5 | AKS | ⬜ Not started | AKS cluster, node pool, ingress controller, HPA, ConfigMaps/Secrets, PVs |
| 6 | Databases | ⬜ Not started | Azure SQL — `users`, `orders`, `products` tables; Cosmos DB later/optional |
| 7 | Messaging | ⬜ Not started | Service Bus — order created → queue → order processor → inventory update |
| 8 | Storage | ⬜ Not started | Storage Account — product images, invoices, log exports |
| 9 | Secrets | ⬜ Not started | Key Vault — DB password, JWT secret, storage key, API keys; AKS reads via managed identity |
| 10 | CI/CD | ⬜ Not started | Azure DevOps Pipelines: build → test → docker build → push ACR → terraform plan/apply → deploy AKS → smoke test |
| 11 | Monitoring | ⬜ Not started | Azure Monitor, Log Analytics, Application Insights, alerts |
| 12 | Security | ⬜ Not started | Network policies, Azure Policy, RBAC hardening, private endpoints, WAF, Defender for Cloud trial |
| 13 | GitOps (optional) | ⬜ Not started | FluxCD/ArgoCD — Git becomes the source of truth instead of direct `kubectl`/pipeline deploys |

## Reference architecture

```
Internet
  -> Azure Front Door (optional)
  -> Application Gateway (WAF)
  -> Azure Load Balancer
  -> Azure Kubernetes Service
       -> User Service | Product Service | Order Service
  -> Azure Service Bus
  -> Azure SQL DB | Azure Cache for Redis
  -> Azure Storage Account
  -> Azure Key Vault
```

## Cost discipline

Target: stay within a $200 Azure credit. AKS (from Phase 5) and the management VM are the dominant costs — stop/deallocate both between sessions rather than leaving them running 24/7. Full breakdown of what's billed and exactly how to stop/delete/recreate each thing: [`docs/cost-management.md`](cost-management.md).

## Where things run, after Phase 2b

Once the management VM exists, it is the place to run Terraform, `kubectl`, `docker build`, and `az` for every phase from 3 onward — not your local machine. Your laptop's job ends at Phase 2b: install a minimal bootstrap toolset, stand up Identity + Networking + the VM itself, then SSH in. See `docs/00-prerequisites.md` and `docs/deployment_phases/phase-02b-management-vm.md`.

## Working agreement for this repo

- Each phase gets a `docs/deployment_phases/phase-NN-<name>.md` covering both the Terraform path and the manual Azure Portal path.
- Terraform modules not yet built contain a `README.md` stating which phase will populate them — check the module directory before assuming something doesn't exist.
- No `terraform apply` or `az` resource-creation commands are run automatically; the user runs them after reviewing, once authenticated locally (or from the management VM, from Phase 2b on).
- `docs/services.md` explains what each of the three demo services does, how they're implemented, and how they communicate — read it alongside each service's own `README.md`.
- `docs/azure-services/` explains each *Azure* service used — what it is, why this project uses it, where it's wired in, and how — one file per service, independent of the phase docs (which focus on the how-to-provision steps).
- `docs/cost-management.md` is the consolidated cost/teardown reference; each phase's own "Teardown" section links back to it rather than repeating it.
