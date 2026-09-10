# Azure Enterprise DevOps Platform

A portfolio-grade, production-style e-commerce platform on Azure. The application (three tiny Node.js services) exists only to prove the infrastructure works — **the point of this repo is the infrastructure**: Terraform, AKS, networking, identity, secrets, messaging, CI/CD, monitoring, and security, built the way a real Azure production environment is built.

Full plan: [`Azure_Ecommerce_Platform_Roadmap.pdf`](Azure_Ecommerce_Platform_Roadmap.pdf) (source roadmap) and [`docs/ROADMAP.md`](docs/ROADMAP.md) (condensed, living checklist — check this one for current status).

## Architecture

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

## Status

| Phase | Status |
|---|---|
| 1 — Identity | ✅ Done |
| 2 — Networking | ✅ Done |
| 2b — Management VM *(custom addition)* | ✅ Done |
| 3 — Infrastructure as Code | ✅ Done |
| 4 — Azure Container Registry | ✅ Done |
| 5 — AKS | ✅ Done |
| 6 — Databases | ✅ Done |
| 7 — Messaging | ✅ Done |
| 8 — Storage | ✅ Done |
| 9 — Secrets | ✅ Done |
| 10 — CI/CD | ✅ Done |
| 11 — Monitoring | ✅ Done |
| 12 — Security | ✅ Done |
| 13 — GitOps *(optional)* | ✅ Done (guidance) |

"Done" = code, manifests, pipelines, and docs are complete and `terraform validate` passes — not that it's running in your subscription. See [`docs/ROADMAP.md`](docs/ROADMAP.md) for the apply-order caveat.

Full table with what each phase builds: [`docs/ROADMAP.md`](docs/ROADMAP.md).

## Two machines: local bootstrap, then an in-Azure admin VM

Phases 1 and 2 run from your local machine. Right after, **Phase 2b provisions a dedicated management VM** inside the VNet (its own subnet, SSH-key-only, no stored secrets — it authenticates via its own managed identity) — every phase from 3 onward runs its Terraform/kubectl/docker/az commands from that VM, not your laptop. See [`docs/00-prerequisites.md`](docs/00-prerequisites.md) §0 and [`docs/deployment_phases/phase-02b-management-vm.md`](docs/deployment_phases/phase-02b-management-vm.md).

## Repo layout

```
docs/
  deployment_phases/   step-by-step instructions, one file per phase (Terraform path + Azure Portal path)
  azure-services/      what each Azure service is, why it's used here, and where it's wired in — independent of the phase how-tos
  aks/                 AKS deep-dive: cluster management, networking, RBAC/identity, storage, service mesh, logging/monitoring, policies/CRDs, troubleshooting
  cost-management.md   consolidated stop/delete/recreate reference for every billed resource
  services.md          how the 3 demo services fit together and communicate
terraform/
  environments/prod/   root module — wires everything together for the prod environment
  modules/             one module per concern (identity, network, management-vm, acr, aks, sql, servicebus, storage, keyvault, monitoring, appgateway, security)
kubernetes/            manifests (namespace, deployments, services, ingress, hpa, secrets, security)
pipelines/             Azure Pipelines YAML — ci.yml + cd.yml
Application_services/ the 3 demo microservices (Node.js + Express)
helm/                  optional packaging layer, for the optional GitOps phase
scripts/               setup/bootstrap/cost-control helpers
```

## Getting started

1. Read [`docs/00-prerequisites.md`](docs/00-prerequisites.md) — install the local bootstrap tools, generate an SSH key, log in, bootstrap the Terraform state backend.
2. Follow [`docs/deployment_phases/phase-01-identity.md`](docs/deployment_phases/phase-01-identity.md), [`docs/deployment_phases/phase-02-networking.md`](docs/deployment_phases/phase-02-networking.md), then [`docs/deployment_phases/phase-02b-management-vm.md`](docs/deployment_phases/phase-02b-management-vm.md) — each has a Terraform track and a manual Azure Portal track.
3. SSH into the management VM and continue from there. Later phases land the same way, one `docs/deployment_phases/phase-NN-*.md` at a time, per [`docs/ROADMAP.md`](docs/ROADMAP.md).

Running the demo services locally (no Azure needed yet): see each service's own README under [`Application_services/`](Application_services), and [`docs/services.md`](docs/services.md) for what each service does, how they're implemented, and how they communicate (today and once messaging lands in Phase 7). For the Azure side, [`docs/azure-services/`](docs/azure-services) explains each Azure service used — what it is, why it's in this project, and where.

## Cost discipline

Target: stay within a ~$200 Azure credit. The dominant costs are AKS (from Phase 5) and the always-on management VM — stop/deallocate both between practice sessions rather than running them 24/7, using `scripts/stop-management-vm.ps1` / `scripts/start-management-vm.ps1`. Full breakdown of every billed resource and exactly how to stop/delete/recreate it: [`docs/cost-management.md`](docs/cost-management.md).
