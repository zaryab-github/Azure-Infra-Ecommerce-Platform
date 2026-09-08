# Phase 5 — AKS

Goal: the cluster running the three services, with an ingress controller, HPA, workload identity, and the Key Vault CSI provider add-on ready for Phase 9.

> **Where this runs**: from the management VM.

## What gets created

| Resource | Purpose |
|---|---|
| `azurerm_kubernetes_cluster` (`Standard_B2s`, 1 node, SKU tier Free) | The cluster, in `snet-aks` |
| AcrPull role assignment | Kubelet identity → ACR (Phase 4) |
| OIDC issuer + workload identity federation | Pods use `id-ecommerce-aks-prod` (Phase 1) via a Kubernetes ServiceAccount, no stored credential |
| Key Vault Secrets Provider add-on | AKS-managed CSI driver for Key Vault (Phase 9 grants it access) |
| Web Application Routing add-on | The ingress controller (nginx-based, Azure-managed) |

See [`docs/azure-services/azure-kubernetes-service.md`](../azure-services/azure-kubernetes-service.md) and [`managed-identity.md`](../azure-services/managed-identity.md).

## Track A — Terraform

```bash
terraform -chdir=terraform/environments/prod plan \
  -target=module.acr -target=module.aks
terraform -chdir=terraform/environments/prod apply \
  -target=module.acr -target=module.aks
```

(`enable_monitoring` defaults to `true` but the monitoring module itself isn't targeted here — the AKS module's `log_analytics_workspace_id` input just resolves to `null` until Phase 11's `module.monitoring` is actually applied, per the comment in `main.tf`.)

## Track B — Azure Portal

1. Inside `rg-ecommerce-prod` → **+ Create a resource** → **Azure Kubernetes Service**.
2. **Basics**: name `aks-ecommerce-prod`, region matching the rest, **Free** tier.
3. **Node pools**: edit the default pool — size `Standard_B2s`, node count 1, **Virtual network**: select `vnet-ecommerce-prod` / `snet-aks`, network plugin **Azure CNI**.
4. **Networking**: network policy **Azure**.
5. **Integrations**: Container registry → select `acrecommerceprod` (Portal wires the AcrPull role assignment automatically). Enable **Key Vault Secrets Provider**.
6. **Add-ons**: enable **Web Application Routing**.
7. **Workload identity**: under Security, enable **OIDC issuer** and **Workload Identity**.
8. After creation, manually create the federated credential: cluster → **Workload Identity** → **+ Add** → select `id-ecommerce-aks-prod`, namespace `ecommerce`, service account name `ecommerce-workload-sa`.

## Deploy the manifests

```bash
az aks get-credentials --name aks-ecommerce-prod --resource-group rg-ecommerce-prod

# Substitute placeholders (see each file's header comment)
sed -i "s#<ACR_LOGIN_SERVER>#$(terraform -chdir=terraform/environments/prod output -raw acr_login_server)#g" kubernetes/deployments/*.yaml
sed -i "s#<WORKLOAD_IDENTITY_CLIENT_ID>#$(terraform -chdir=terraform/environments/prod output -raw aks_workload_identity_client_id 2>/dev/null || echo)#g" kubernetes/serviceaccount.yaml

kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/serviceaccount.yaml
kubectl apply -f kubernetes/deployments/
kubectl apply -f kubernetes/services/
kubectl apply -f kubernetes/ingress/
kubectl apply -f kubernetes/hpa/
```

Note: `kubernetes/deployments/*.yaml` still has `<SQL_SERVER_FQDN>` etc. placeholders — fine for now, the pods start and serve their in-memory fallback data (see `docs/services.md`); Phase 6 fills those in.

## Verification

```bash
kubectl get nodes
kubectl get pods -n ecommerce
kubectl get svc -n app-routing-system nginx
curl http://<ingress-ip>/api/users
```

## Cost / Teardown

AKS is the dominant cost in this project. Stop between sessions:

```bash
az aks stop --name aks-ecommerce-prod --resource-group rg-ecommerce-prod
az aks start --name aks-ecommerce-prod --resource-group rg-ecommerce-prod
```

See [`docs/cost-management.md`](../cost-management.md) for full teardown/recreate if pausing longer.

## Next

Phase 6 — Databases.
