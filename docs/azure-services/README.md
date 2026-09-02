# Azure services reference

While [`docs/deployment_phases/`](../deployment_phases) explains *how to provision* each phase (Terraform steps + Portal steps), this directory explains **what each individual Azure service actually is, why this project uses it, and where it's wired in**. Read the phase doc for the how-to; read the matching file here for the why.

| Area | Azure service | Used since | Doc |
|---|---|---|---|
| Resource organization | Resource Group | Phase 1 | [resource-groups.md](resource-groups.md) |
| IAM | Microsoft Entra ID (App Registration + Service Principal) | Phase 1 | [entra-id-and-service-principals.md](entra-id-and-service-principals.md) |
| RBAC | Azure RBAC (role assignments) | Phase 1 | [azure-rbac.md](azure-rbac.md) |
| Identity | Managed Identity (user-assigned + system-assigned) | Phase 1 (created), Phase 2b (used) | [managed-identity.md](managed-identity.md) |
| Networking | Virtual Network & Subnets | Phase 2 | [virtual-network-and-subnets.md](virtual-network-and-subnets.md) |
| Security | Network Security Groups | Phase 2 | [network-security-groups.md](network-security-groups.md) |
| Networking | Route Tables | Phase 2 | [route-tables.md](route-tables.md) |
| Networking | NAT Gateway & Public IP | Phase 2 | [nat-gateway-and-public-ip.md](nat-gateway-and-public-ip.md) |
| Compute | Virtual Machine (management/admin VM) | Phase 2b | [virtual-machines.md](virtual-machines.md) |
| Container Registry | Azure Container Registry | Phase 4 | [azure-container-registry.md](azure-container-registry.md) *(not yet implemented)* |
| Kubernetes | Azure Kubernetes Service | Phase 5 | [azure-kubernetes-service.md](azure-kubernetes-service.md) *(not yet implemented)* |
| Networking | Azure Load Balancer | Phase 5 | [azure-load-balancer.md](azure-load-balancer.md) *(not yet implemented)* |
| Reverse proxy / WAF | Application Gateway | Phase 5 / 12 | [application-gateway-waf.md](application-gateway-waf.md) *(not yet implemented)* |
| Databases | Azure SQL Database | Phase 6 | [azure-sql-database.md](azure-sql-database.md) *(not yet implemented)* |
| Caching | Azure Cache for Redis | Phase 6 | [azure-cache-for-redis.md](azure-cache-for-redis.md) *(not yet implemented)* |
| Messaging | Azure Service Bus | Phase 7 | [azure-service-bus.md](azure-service-bus.md) *(not yet implemented)* |
| Object storage | Azure Storage Account | Phase 8 | [azure-storage-account.md](azure-storage-account.md) *(not yet implemented)* |
| Secrets | Azure Key Vault | Phase 9 | [azure-key-vault.md](azure-key-vault.md) *(not yet implemented)* |
| CI/CD | Azure DevOps Pipelines | Phase 10 | [azure-devops-pipelines.md](azure-devops-pipelines.md) *(not yet implemented)* |
| Monitoring / Logs / Tracing | Azure Monitor, Log Analytics, Application Insights | Phase 11 | [azure-monitor-log-analytics-app-insights.md](azure-monitor-log-analytics-app-insights.md) *(not yet implemented)* |
| Governance / Security | Azure Policy, Microsoft Defender for Cloud | Phase 12 | [azure-policy-and-defender.md](azure-policy-and-defender.md) *(not yet implemented)* |
| DNS | Azure DNS | Optional | [azure-dns.md](azure-dns.md) *(not yet implemented)* |

Each "not yet implemented" file follows the same pattern as the placeholder `README.md`s under `terraform/modules/` — a short note on what the service is and which phase will bring it in, so the shape of the full architecture is visible even before it's built.
