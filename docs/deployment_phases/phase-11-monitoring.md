# Phase 11 — Monitoring

Goal: Log Analytics collecting AKS container logs, Application Insights tracing requests from the three services, diagnostic settings on Key Vault/SQL, and two baseline alerts.

> **Where this runs**: from the management VM.

## What gets created

| Resource | Purpose |
|---|---|
| `azurerm_log_analytics_workspace` | Central log store — also wired back into AKS's container insights (Phase 5's `oms_agent`, via `enable_monitoring`) |
| `azurerm_application_insights` (workspace-based) | Request tracing from the services |
| Diagnostic settings on Key Vault + SQL | Forward audit logs / query insights to the workspace |
| Action group + 2 metric alerts (AKS node CPU, SQL CPU, both >80%) | Email notification |

See [`docs/azure-services/azure-monitor-log-analytics-app-insights.md`](../azure-services/azure-monitor-log-analytics-app-insights.md).

## Track A — Terraform

Set `alert_email` in `terraform.tfvars` first (no default — deliberate). Then:

```bash
terraform -chdir=terraform/environments/prod plan -target=module.monitoring
terraform -chdir=terraform/environments/prod apply -target=module.monitoring
```

Since `enable_monitoring` defaults to `true` and `module.aks` references `module.monitoring[0].log_analytics_workspace_id`, this apply also updates the AKS cluster in place to turn on the `oms_agent` container-insights add-on — expect `azurerm_kubernetes_cluster.main` to show as "updated" in the plan, not just new monitoring resources.

## Track B — Azure Portal

1. Inside `rg-ecommerce-prod` → **+ Create a resource** → **Log Analytics workspace** → name `log-ecommerce-prod`.
2. **+ Create a resource** → **Application Insights** → **Resource Mode: Workspace-based** → link to the workspace above.
3. On the AKS cluster → **Insights** → **Enable** → select the same workspace (this is the Portal equivalent of the `oms_agent` block).
4. On the Key Vault and SQL database → **Diagnostic settings** → **+ Add** → send to the same workspace.
5. **+ Create a resource** → **Alert rule** × 2 (AKS node CPU, SQL CPU) → **Action group** → **Email** → your address.

## Wire Application Insights into the services

```bash
AI_CONN=$(terraform -chdir=terraform/environments/prod output -raw app_insights_connection_string 2>/dev/null)
sed -i "s#<APP_INSIGHTS_CONNECTION_STRING>#$AI_CONN#g" kubernetes/deployments/*.yaml
kubectl apply -f kubernetes/deployments/
```

## Verification

```bash
kubectl logs -n ecommerce deployment/user-service | head
# Azure Portal → Application Insights → Live Metrics, after a few requests
curl http://<ingress-ip>/api/users
```

## Cost / Teardown

Log Analytics bills on ingestion volume — keep it low at this project's traffic. See [`docs/cost-management.md`](../cost-management.md).

## Next

Phase 12 — Security.
